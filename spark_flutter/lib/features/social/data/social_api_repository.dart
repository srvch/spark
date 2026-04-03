import 'package:dio/dio.dart';

import '../domain/social.dart';

class SocialApiRepository {
  SocialApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<FriendUser>> fetchFriends() async {
    final response = await _dio.get<dynamic>('/api/v1/social/friends');
    final rows = response.data is List ? response.data as List : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => FriendUser(
            userId: '${json['userId']}',
            displayName: '${json['displayName']}',
            phoneNumber: '${json['phoneNumber']}',
          ),
        )
        .toList();
  }

  Future<List<IncomingFriendRequest>> fetchIncomingFriendRequests() async {
    final response = await _dio.get<dynamic>(
      '/api/v1/social/friends/requests/incoming',
    );
    final rows = response.data is List ? response.data as List : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => IncomingFriendRequest(
            requestId: '${json['requestId']}',
            fromUserId: '${json['fromUserId']}',
            displayName: '${json['displayName']}',
            phoneNumber: '${json['phoneNumber']}',
            createdAt:
                DateTime.tryParse('${json['createdAt']}')?.toLocal() ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> sendFriendRequest({required String phoneNumber}) async {
    await _dio.post<dynamic>(
      '/api/v1/social/friends/request',
      data: {'phoneNumber': phoneNumber},
    );
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required InviteDecision decision,
  }) async {
    await _dio.post<dynamic>(
      '/api/v1/social/friends/requests/$requestId/respond',
      data: {
        'status': decision == InviteDecision.accepted ? 'ACCEPTED' : 'DECLINED',
      },
    );
  }

  Future<void> unfriend({required String userId}) async {
    await _dio.delete<dynamic>('/api/v1/social/friends/$userId');
  }

  Future<List<SparkGroup>> fetchGroups() async {
    final response = await _dio.get<dynamic>('/api/v1/social/groups');
    final rows = response.data is List ? response.data as List : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => SparkGroup(
            groupId: '${json['groupId']}',
            name: '${json['name']}',
            description: '${json['description'] ?? ''}',
            ownerUserId: '${json['ownerUserId']}',
            myRole: '${json['myRole']}',
            memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<GroupDetail> fetchGroupDetail(String groupId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/social/groups/$groupId',
    );
    final data = response.data ?? const <String, dynamic>{};
    final members = (data['members'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => GroupMember(
            userId: '${json['userId']}',
            displayName: '${json['displayName']}',
            phoneNumber: '${json['phoneNumber']}',
            role: '${json['role']}',
          ),
        )
        .toList();
    return GroupDetail(
      groupId: '${data['groupId']}',
      name: '${data['name']}',
      description: '${data['description'] ?? ''}',
      ownerUserId: '${data['ownerUserId']}',
      myRole: '${data['myRole']}',
      members: members,
    );
  }

  Future<GroupSummary> createGroup({
    required String name,
    required String description,
  }) async {
    final response = await _dio.post<dynamic>(
      '/api/v1/social/groups',
      data: {'name': name, 'description': description},
    );
    final data = response.data as Map<String, dynamic>;
    return GroupSummary(
      groupId: '${data['groupId'] ?? data['id']}',
      name: '${data['name']}',
      description: '${data['description'] ?? ''}',
      ownerUserId: '${data['ownerUserId']}',
      myRole: '${data['myRole']}',
      memberCount: int.tryParse('${data['memberCount']}') ?? 1,
    );
  }

  Future<void> inviteFriendToGroup({
    required String groupId,
    required String userId,
  }) async {
    await _dio.post<dynamic>(
      '/api/v1/social/groups/$groupId/invite',
      data: {'userId': userId},
    );
  }

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String userId,
  }) async {
    await _dio.delete<dynamic>(
      '/api/v1/social/groups/$groupId/members/$userId',
    );
  }

  Future<void> nudgePendingMember({
    required String groupId,
    required String userId,
  }) async {
    await _dio.post<dynamic>(
      '/api/v1/social/groups/$groupId/members/$userId/nudge',
    );
  }

  Future<List<GroupInviteInboxItem>> fetchIncomingGroupInvites() async {
    final response = await _dio.get<dynamic>(
      '/api/v1/social/groups/invites/incoming',
    );
    final rows = response.data is List ? response.data as List : const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => GroupInviteInboxItem(
            inviteId: '${json['inviteId']}',
            groupId: '${json['groupId']}',
            groupName: '${json['groupName']}',
            inviterUserId: '${json['inviterUserId']}',
            inviterName: '${json['inviterName']}',
            createdAt:
                DateTime.tryParse('${json['createdAt']}')?.toLocal() ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> respondGroupInvite({
    required String groupId,
    required String inviteId,
    required InviteDecision decision,
  }) async {
    await _dio.post<dynamic>(
      '/api/v1/social/groups/$groupId/invites/$inviteId/respond',
      data: {
        'status': decision == InviteDecision.accepted ? 'ACCEPTED' : 'DECLINED',
      },
    );
  }
}
