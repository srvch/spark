import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/firebase/firebase_bootstrap.dart';
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

  Future<FirebaseAuth> _authClient() async {
    final app = await ensureFirebaseInitialized();
    if (!kReleaseMode && Platform.isIOS) {
      await FirebaseAuth.instanceFor(
        app: app,
      ).setSettings(appVerificationDisabledForTesting: true);
    }
    return FirebaseAuth.instanceFor(app: app);
  }

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
      final auth = await _authClient();
      await auth.verifyPhoneNumber(
        phoneNumber: normalized,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (e.g. on Android) - not common on iOS during debug
          await _signInWithCredential(credential, normalized);
        },
        verificationFailed: (FirebaseAuthException e) {
          state = AuthUiState(
            loading: false,
            error: _readableFirebaseAuthError(e),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          state = AuthUiState(loading: false, requestId: verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          state = state.copyWith(requestId: verificationId);
        },
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        state = AuthUiState(
          loading: false,
          error: _readableFirebaseAuthError(e),
        );
        return;
      }
      state = AuthUiState(loading: false, error: e.toString());
    }
  }

  Future<void> verifyOtp({required String phone, required String otp}) async {
    final verificationId = state.requestId;
    if (verificationId == null) {
      state = state.copyWith(error: 'Request OTP first.');
      return;
    }
    state = state.copyWith(loading: true, error: null);

    try {
      await _authClient();
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      await _signInWithCredential(credential, phone);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Invalid code. Please try again.',
      );
    }
  }

  Future<void> _signInWithCredential(
    PhoneAuthCredential credential,
    String phone,
  ) async {
    state = state.copyWith(loading: true);
    try {
      final auth = await _authClient();
      final userCred = await auth.signInWithCredential(credential);
      final idToken = await userCred.user?.getIdToken();

      if (idToken == null) {
        throw Exception('Failed to get ID token from Firebase.');
      }

      final session = await ref
          .read(authApiRepositoryProvider)
          .firebaseLogin(idToken: idToken);

      ref.read(authSessionProvider.notifier).state = session;
      ref.read(guestShowcaseModeProvider.notifier).state = false;
      unawaited(
        ref.read(pushRegistrationServiceProvider).registerDeviceToken(session),
      );
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
      ref.read(guestShowcaseModeProvider.notifier).state = true;
      state = const AuthUiState(loading: false);
    } catch (e) {
      ref.read(authSessionProvider.notifier).state =
          buildGuestShowcaseSession();
      ref.read(guestShowcaseModeProvider.notifier).state = true;
      state = const AuthUiState(loading: false);
    }
  }

  /// Signs the user out: unregisters push token, clears Firebase session,
  /// and clears the local Spark session (triggers SharedPreferences clear
  /// and navigation back to login via SparkApp's ref.listen).
  Future<void> logout() async {
    // 1. Unregister FCM token from backend (best-effort)
    unawaited(
      ref.read(pushRegistrationServiceProvider).unregisterDeviceToken(),
    );

    // 2. Sign out from Firebase
    try {
      final auth = await _authClient();
      await auth.signOut();
    } catch (_) {}

    // 3. Clear Spark session — SparkApp ref.listen will clear SharedPreferences
    //    and navigate back to PhoneLoginScreen automatically.
    ref.read(authSessionProvider.notifier).state = null;
    ref.read(guestShowcaseModeProvider.notifier).state = false;

    // 4. Reset auth UI state
    state = const AuthUiState();
  }

  /// Permanently deletes the user account and all associated data.
  Future<void> deleteAccount() async {
    // 1. Unregister FCM token (best-effort)
    unawaited(
      ref.read(pushRegistrationServiceProvider).unregisterDeviceToken(),
    );

    // 2. Call backend — cascades delete of all user data
    await ref.read(authApiRepositoryProvider).deleteAccount();

    // 3. Sign out from Firebase
    try {
      final auth = await _authClient();
      await auth.signOut();
    } catch (_) {}

    // 4. Clear session → navigates to PhoneLoginScreen
    ref.read(authSessionProvider.notifier).state = null;
    ref.read(guestShowcaseModeProvider.notifier).state = false;
    state = const AuthUiState();
  }

  Future<void> completeMandatoryProfile({
    required String displayName,
    required String ageBand,
    required String gender,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final profile = await ref
          .read(authApiRepositoryProvider)
          .completeProfile(
            displayName: displayName,
            ageBand: ageBand,
            gender: gender,
          );
      final current = ref.read(authSessionProvider);
      if (current != null) {
        ref.read(authSessionProvider.notifier).state = AuthSession(
          token: current.token,
          userId: current.userId,
          phoneNumber: current.phoneNumber,
          displayName: profile.displayName,
          ageBand: profile.ageBand,
          gender: profile.gender,
          hidePhoneNumber: current.hidePhoneNumber,
        );
      }
      state = const AuthUiState(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: _readableError(e));
    }
  }

  String _readableError(Object error) {
    if (error is FirebaseException) {
      final message = (error.message ?? '').toLowerCase();
      if (message.contains('[default]') || message.contains("doesn't exist")) {
        return 'Firebase app was not ready. Please tap Verify once again.';
      }
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return '${data['error']}';
      }
      return error.message ?? 'Request failed. Please try again.';
    }
    return error.toString();
  }

  String _readableFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number with country code.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'quota-exceeded':
        return 'OTP quota exceeded for this Firebase project.';
      case 'operation-not-allowed':
        return 'Phone sign-in is disabled in Firebase Console.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please try again.';
      case 'app-not-authorized':
        return 'This iOS app is not authorized in Firebase project settings.';
      case 'internal-error':
        return 'Firebase internal auth error. Check iOS Firebase config and URL scheme.';
      default:
        return error.message ?? 'Phone verification failed. Please try again.';
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>((ref) {
      return AuthController(ref);
    });
