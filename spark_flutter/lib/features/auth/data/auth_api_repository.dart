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
      handle: data['handle']?.toString(),
      ageBand: data['ageBand']?.toString(),
      gender: data['gender']?.toString(),
    );
  }

  Future<AuthSession> firebaseLogin({
    required String idToken,
    String? displayName,
  }) async {
    final payload = <String, dynamic>{
      'idToken': idToken,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      payload['displayName'] = displayName.trim();
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/firebase/verify',
      data: payload,
    );
    final data = response.data ?? const {};
    return AuthSession(
      token: '${data['token']}',
      userId: '${data['userId']}',
      phoneNumber: '${data['phoneNumber']}',
      displayName: '${data['displayName']}',
      handle: data['handle']?.toString(),
      ageBand: data['ageBand']?.toString(),
      gender: data['gender']?.toString(),
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
      handle: data['handle']?.toString(),
      ageBand: data['ageBand']?.toString(),
      gender: data['gender']?.toString(),
    );
  }

  Future<OnboardingProfile> completeProfile({
    required String displayName,
    required String handle,
    required String ageBand,
    required String gender,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/users/me',
      data: {
        'displayName': displayName.trim(),
        'handle': handle.trim(),
        'ageBand': ageBand,
        'gender': gender,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    return OnboardingProfile(
      userId: '${data['userId']}',
      displayName: '${data['displayName']}',
      handle: '${data['handle'] ?? handle}',
      phoneNumber: '${data['phoneNumber']}',
      ageBand: data['ageBand']?.toString() ?? ageBand,
      gender: data['gender']?.toString() ?? gender,
    );
  }

  Future<OnboardingProfile> fetchMyProfile({
    required String token,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users/me',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final data = response.data ?? const <String, dynamic>{};
    return OnboardingProfile(
      userId: '${data['userId']}',
      displayName: '${data['displayName']}',
      handle: '${data['handle'] ?? ''}',
      phoneNumber: '${data['phoneNumber']}',
      ageBand: data['ageBand']?.toString() ?? '',
      gender: data['gender']?.toString() ?? '',
    );
  }

  Future<void> deleteAccount() async {
    await _dio.delete<void>('/api/v1/users/me');
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

class OnboardingProfile {
  const OnboardingProfile({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.phoneNumber,
    required this.ageBand,
    required this.gender,
  });

  final String userId;
  final String displayName;
  final String handle;
  final String phoneNumber;
  final String ageBand;
  final String gender;
}
