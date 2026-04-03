import 'package:dio/dio.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.phoneNumber,
    required this.memberSince,
  });

  final String userId;
  final String displayName;
  final String phoneNumber;
  final DateTime memberSince;

  UserProfile copyWith({String? displayName}) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber,
      memberSince: memberSince,
    );
  }
}

class ProfileApiRepository {
  ProfileApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<UserProfile> fetchProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
    final data = response.data ?? const <String, dynamic>{};
    return UserProfile(
      userId: '${data['userId']}',
      displayName: '${data['displayName']}',
      phoneNumber: '${data['phoneNumber']}',
      memberSince: DateTime.tryParse('${data['createdAt']}') ?? DateTime.now(),
    );
  }

  Future<UserProfile> updateProfile({required String displayName}) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/users/me',
      data: {'displayName': displayName},
    );
    final data = response.data ?? const <String, dynamic>{};
    return UserProfile(
      userId: '${data['userId']}',
      displayName: '${data['displayName']}',
      phoneNumber: '${data['phoneNumber']}',
      memberSince: DateTime.tryParse('${data['createdAt']}') ?? DateTime.now(),
    );
  }
}
