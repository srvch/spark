import 'dart:async';

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
    this.requestId,
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

  Future<void> requestOtp(String phone) async {
    state = const AuthUiState(loading: true);
    try {
      final result = await ref.read(authApiRepositoryProvider).requestOtp(phone);
      state = AuthUiState(
        loading: false,
        requestId: result.requestId,
        debugOtp: result.debugOtp,
      );
    } catch (e) {
      state = AuthUiState(loading: false, error: _readableError(e));
    }
  }

  Future<void> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final requestId = state.requestId;
    if (requestId == null) {
      state = state.copyWith(error: 'Request OTP first.');
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final session = await ref.read(authApiRepositoryProvider).verifyOtp(
        requestId: requestId,
        phoneNumber: phone,
        otp: otp,
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

  String _readableError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null) {
        return '${data['error']}';
      }
      return error.message ?? 'Request failed. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>((ref) {
      return AuthController(ref);
    });
