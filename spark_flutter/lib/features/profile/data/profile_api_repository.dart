import 'package:dio/dio.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.phoneNumber,
    required this.memberSince,
    required this.ageBand,
    required this.gender,
    this.hidePhoneNumber = true,
  });

  final String userId;
  final String displayName;
  final String handle;
  final String phoneNumber;
  final DateTime memberSince;
  final String ageBand;
  final String gender;
  final bool hidePhoneNumber;

  UserProfile copyWith({
    String? displayName,
    String? handle,
    String? ageBand,
    String? gender,
    bool? hidePhoneNumber,
  }) {
    return UserProfile(
      userId: userId,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      phoneNumber: phoneNumber,
      memberSince: memberSince,
      ageBand: ageBand ?? this.ageBand,
      gender: gender ?? this.gender,
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
      handle: '${data['handle'] ?? ''}',
      phoneNumber: '${data['phoneNumber']}',
      memberSince: DateTime.tryParse('${data['createdAt']}') ?? DateTime.now(),
      ageBand: '${data['ageBand'] ?? ''}',
      gender: '${data['gender'] ?? ''}',
      hidePhoneNumber: data['hidePhoneNumber'] == true,
    );
  }

  Future<UserProfile> updateProfile({
    required String displayName,
    required String handle,
    required String ageBand,
    required String gender,
    bool? hidePhoneNumber,
  }) async {
    final Map<String, dynamic> updateData = {};
    updateData['displayName'] = displayName;
    updateData['handle'] = handle;
    updateData['ageBand'] = ageBand;
    updateData['gender'] = gender;
    if (hidePhoneNumber != null) updateData['hidePhoneNumber'] = hidePhoneNumber;

    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/users/me',
      data: updateData,
    );
    final data = response.data ?? const <String, dynamic>{};
    return UserProfile(
      userId: '${data['userId']}',
      displayName: '${data['displayName']}',
      handle: '${data['handle'] ?? ''}',
      phoneNumber: '${data['phoneNumber']}',
      memberSince: DateTime.tryParse('${data['createdAt']}') ?? DateTime.now(),
      ageBand: '${data['ageBand'] ?? ''}',
      gender: '${data['gender'] ?? ''}',
      hidePhoneNumber: data['hidePhoneNumber'] == true,
    );
  }
}
