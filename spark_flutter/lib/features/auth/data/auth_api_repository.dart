import 'package:dio/dio.dart';

import '../../../core/auth/auth_state.dart';

class AuthApiRepository {
  AuthApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<OtpRequestResult> requestOtp(String phoneNumber) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/otp/request',
      data: {'phoneNumber': phoneNumber},
    );
    final data = response.data ?? const {};
    return OtpRequestResult(
      requestId: '${data['requestId']}',
      expiresInSeconds: (data['expiresInSeconds'] as num?)?.toInt() ?? 180,
      debugOtp: '${data['debugOtp'] ?? ''}',
    );
  }

  Future<AuthSession> verifyOtp({
    required String requestId,
    required String phoneNumber,
    required String otp,
    String? displayName,
  }) async {
    final payload = <String, dynamic>{
      'requestId': requestId,
      'phoneNumber': phoneNumber,
      'otp': otp,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      payload['displayName'] = displayName.trim();
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/otp/verify',
      data: payload,
    );
    final data = response.data ?? const {};
    return AuthSession(
      token: '${data['token']}',
      userId: '${data['userId']}',
      phoneNumber: '${data['phoneNumber']}',
      displayName: '${data['displayName']}',
    );
  }

  Future<AuthSession> loginAsGuest() async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/auth/dev/guest');
    final data = response.data ?? const {};
    return AuthSession(
      token: '${data['token']}',
      userId: '${data['userId']}',
      phoneNumber: '${data['phoneNumber']}',
      displayName: '${data['displayName']}',
    );
  }
}

class OtpRequestResult {
  const OtpRequestResult({
    required this.requestId,
    required this.expiresInSeconds,
    required this.debugOtp,
  });

  final String requestId;
  final int expiresInSeconds;
  final String debugOtp;
}
