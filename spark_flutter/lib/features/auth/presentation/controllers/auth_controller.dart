import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/push/push_registration_service.dart';
import '../../data/auth_api_repository.dart';

final authApiRepositoryProvider = Provider<AuthApiRepository>((ref) {
  return AuthApiRepository(dio: ref.watch(dioProvider));
});

class AuthUiState {
  const AuthUiState({
    this.loading = false,
    this.requestId, // In Firebase this is verificationId
    this.debugOtp,
    this.error,
  });

  final bool loading;
  final String? requestId;
  final String? debugOtp;
  final String? error;

  bool get otpRequested => requestId != null;

  AuthUiState copyWith({
    bool? loading,
    String? requestId,
    String? debugOtp,
    String? error,
  }) {
    return AuthUiState(
      loading: loading ?? this.loading,
      requestId: requestId ?? this.requestId,
      debugOtp: debugOtp ?? this.debugOtp,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthUiState> {
  AuthController(this.ref) : super(const AuthUiState());

  final Ref ref;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> requestOtp(String phone) async {
    state = const AuthUiState(loading: true);
    
    // Normalize phone for Firebase
    String normalized = phone.trim();
    if (!normalized.startsWith('+')) {
      if (normalized.length == 10) {
        normalized = '+91$normalized';
      } else {
        normalized = '+$normalized';
      }
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: normalized,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (e.g. on Android) - not common on iOS during debug
          await _signInWithCredential(credential, normalized);
        },
        verificationFailed: (FirebaseAuthException e) {
          state = AuthUiState(loading: false, error: e.message ?? 'Verification failed.');
        },
        codeSent: (String verificationId, int? resendToken) {
          state = AuthUiState(
            loading: false,
            requestId: verificationId,
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = state.copyWith(requestId: verificationId);
        },
      );
    } catch (e) {
      state = AuthUiState(loading: false, error: e.toString());
    }
  }

  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final verificationId = state.requestId;
    if (verificationId == null) {
      state = state.copyWith(error: 'Request OTP first.');
      return;
    }
    state = state.copyWith(loading: true, error: null);
    
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      await _signInWithCredential(credential, phone);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Invalid code. Please try again.');
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential, String phone) async {
    state = state.copyWith(loading: true);
    try {
      final userCred = await _auth.signInWithCredential(credential);
      final idToken = await userCred.user?.getIdToken();
      
      if (idToken == null) {
        throw Exception('Failed to get ID token from Firebase.');
      }

      final session = await ref.read(authApiRepositoryProvider).firebaseLogin(
        idToken: idToken,
      );
      
      ref.read(authSessionProvider.notifier).state = session;
      unawaited(ref.read(pushRegistrationServiceProvider).registerDeviceToken(session));
      state = const AuthUiState(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: _readableError(e));
    }
  }

  Future<void> loginAsGuest() async {
    state = const AuthUiState(loading: true);
    try {
      final session = await ref.read(authApiRepositoryProvider).loginAsGuest();
      ref.read(authSessionProvider.notifier).state = session;
      unawaited(ref.read(pushRegistrationServiceProvider).registerDeviceToken(session));
      state = const AuthUiState(loading: false);
    } catch (e) {
      state = AuthUiState(loading: false, error: _readableError(e));
    }
  }

  /// Signs the user out: unregisters push token, clears Firebase session,
  /// and clears the local Spark session (triggers SharedPreferences clear
  /// and navigation back to login via SparkApp's ref.listen).
  Future<void> logout() async {
    // 1. Unregister FCM token from backend (best-effort)
    unawaited(ref.read(pushRegistrationServiceProvider).unregisterDeviceToken());

    // 2. Sign out from Firebase
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthController] Firebase signOut error: $e');
    }

    // 3. Clear Spark session — SparkApp ref.listen will clear SharedPreferences
    //    and navigate back to PhoneLoginScreen automatically.
    ref.read(authSessionProvider.notifier).state = null;

    // 4. Reset auth UI state
    state = const AuthUiState();
  }

  /// Permanently deletes the user account and all associated data.
  Future<void> deleteAccount() async {
    // 1. Unregister FCM token (best-effort)
    unawaited(ref.read(pushRegistrationServiceProvider).unregisterDeviceToken());

    // 2. Call backend — cascades delete of all user data
    await ref.read(authApiRepositoryProvider).deleteAccount();

    // 3. Sign out from Firebase
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthController] Firebase signOut after deletion error: $e');
    }

    // 4. Clear session → navigates to PhoneLoginScreen
    ref.read(authSessionProvider.notifier).state = null;
    state = const AuthUiState();
  }

  String _readableError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return '${data['error']}';
      }
      return error.message ?? 'Request failed. Please try again.';
    }
    return error.toString();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>((ref) {
  return AuthController(ref);
});
