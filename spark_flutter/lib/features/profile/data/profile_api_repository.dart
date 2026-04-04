import 'package:dio/dio.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.phoneNumber,
    required this.memberSince,
    this.hidePhoneNumber = true,
  });

  final String userId;
  final String displayName;
  final String phoneNumber;
  final DateTime memberSince;
  final bool hidePhoneNumber;

  UserProfile copyWith({String? displayName, bool? hidePhoneNumber}) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber,
      memberSince: memberSince,
      hidePhoneNumber: hidePhoneNumber ?? this.hidePhoneNumber,
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
      hidePhoneNumber: data['hidePhoneNumber'] == true,
    );
  }

  Future<UserProfile> updateProfile({String? displayName, bool? hidePhoneNumber}) async {
    final Map<String, dynamic> updateData = {};
    if (displayName != null) updateData['displayName'] = displayName;
    if (hidePhoneNumber != null) updateData['hidePhoneNumber'] = hidePhoneNumber;

    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/users/me',
      data: updateData,
    );
    final data = response.data ?? const <String, dynamic>{};
    return UserProfile(
      userId: '${data['userId']}',
      displayName: '${data['displayName']}',
      phoneNumber: '${data['phoneNumber']}',
      memberSince: DateTime.tryParse('${data['createdAt']}') ?? DateTime.now(),
      hidePhoneNumber: data['hidePhoneNumber'] == true,
    );
  }
}
