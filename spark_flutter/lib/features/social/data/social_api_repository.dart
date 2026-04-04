import 'package:dio/dio.dart';

import '../domain/social.dart';

class SocialApiRepository {
  SocialApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  // ─── Friends ─────────────────────────────────────────────────────────────

  Future<List<FriendUser>> fetchFriends() async {
    final response = await _dio.get<dynamic>('/api/v1/social/friends');
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => FriendUser(
          userId: '${json['userId']}',
          displayName: '${json['displayName']}',
          phoneNumber: '${json['phoneNumber']}',
          availabilityStatus: '${json['availabilityStatus'] ?? 'NONE'}',
          hidePhoneNumber: json['hidePhoneNumber'] == true,
        )).toList();
  }

  Future<List<IncomingFriendRequest>> fetchIncomingFriendRequests() async {
    final response = await _dio.get<dynamic>('/api/v1/social/friends/requests/incoming');
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => IncomingFriendRequest(
          requestId: '${json['requestId']}',
          fromUserId: '${json['fromUserId']}',
          displayName: '${json['displayName']}',
          phoneNumber: '${json['phoneNumber']}',
          createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
          message: json['message'] as String?,
          hidePhoneNumber: json['hidePhoneNumber'] == true,
        )).toList();
  }

  Future<List<OutgoingFriendRequest>> fetchOutgoingFriendRequests() async {
    final response = await _dio.get<dynamic>('/api/v1/social/friends/requests/outgoing');
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => OutgoingFriendRequest(
          requestId: '${json['requestId']}',
          toUserId: '${json['toUserId']}',
          displayName: '${json['displayName']}',
          phoneNumber: '${json['phoneNumber']}',
          createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
          message: json['message'] as String?,
          hidePhoneNumber: json['hidePhoneNumber'] == true,
        )).toList();
  }

  Future<void> sendFriendRequest({
    required String phoneNumber,
    String? message,
  }) async {
    await _dio.post<dynamic>(
      '/api/v1/social/friends/request',
      data: {
        'phoneNumber': phoneNumber,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required InviteDecision decision,
  }) async {
    await _dio.post<dynamic>(
      '/api/v1/social/friends/requests/$requestId/respond',
      data: {'status': decision == InviteDecision.accepted ? 'ACCEPTED' : 'DECLINED'},
    );
  }

  Future<void> cancelFriendRequest({required String requestId}) async {
    await _dio.delete<dynamic>('/api/v1/social/friends/requests/$requestId');
  }

  Future<void> unfriend({required String userId}) async {
    await _dio.delete<dynamic>('/api/v1/social/friends/$userId');
  }

  // ─── Suggestions + Contacts ───────────────────────────────────────────────

  Future<List<FriendSuggestion>> fetchFriendSuggestions() async {
    final response = await _dio.get<dynamic>('/api/v1/social/friends/suggestions');
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => FriendSuggestion(
          userId: '${json['userId']}',
          displayName: '${json['displayName']}',
          phoneNumber: '${json['phoneNumber']}',
          mutualGroupCount: (json['mutualGroupCount'] as num?)?.toInt() ?? 0,
          hidePhoneNumber: json['hidePhoneNumber'] == true,
        )).toList();
  }

  Future<List<MatchedContact>> matchContacts(List<String> phoneNumbers) async {
    final response = await _dio.post<dynamic>(
      '/api/v1/social/contacts/match',
      data: {'phoneNumbers': phoneNumbers},
    );
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => MatchedContact(
          userId: '${json['userId']}',
          displayName: '${json['displayName']}',
          phoneNumber: '${json['phoneNumber']}',
          alreadyFriend: json['alreadyFriend'] == true,
          hidePhoneNumber: json['hidePhoneNumber'] == true,
        )).toList();
  }

  // ─── Availability ─────────────────────────────────────────────────────────

  Future<void> setAvailability({required String status}) async {
    await _dio.put<dynamic>(
      '/api/v1/social/availability',
      data: {'status': status},
    );
  }

  // ─── Block / Report ───────────────────────────────────────────────────────

  Future<void> blockUser({required String userId}) async {
    await _dio.post<dynamic>('/api/v1/social/block/$userId');
  }

  Future<void> reportUser({required String userId, String? reason}) async {
    await _dio.post<dynamic>(
      '/api/v1/social/report/$userId',
      data: {'reason': reason ?? ''},
    );
  }

  // ─── Groups ───────────────────────────────────────────────────────────────

  Future<List<SparkGroup>> fetchGroups() async {
    final response = await _dio.get<dynamic>('/api/v1/social/groups');
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => SparkGroup(
          groupId: '${json['groupId']}',
          name: '${json['name']}',
          description: '${json['description'] ?? ''}',
          ownerUserId: '${json['ownerUserId']}',
          myRole: '${json['myRole']}',
          memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
          archived: json['archived'] == true,
        )).toList();
  }

  Future<GroupDetail> fetchGroupDetail(String groupId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/social/groups/$groupId');
    final data = response.data ?? const <String, dynamic>{};
    final members = (data['members'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((json) => GroupMember(
              userId: '${json['userId']}',
              displayName: '${json['displayName']}',
              phoneNumber: '${json['phoneNumber']}',
              role: '${json['role']}',
              hidePhoneNumber: json['hidePhoneNumber'] == true,
            ))
        .toList();
    return GroupDetail(
      groupId: '${data['groupId']}',
      name: '${data['name']}',
      description: '${data['description'] ?? ''}',
      ownerUserId: '${data['ownerUserId']}',
      myRole: '${data['myRole']}',
      members: members,
      archived: data['archived'] == true,
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

  Future<void> updateGroup({
    required String groupId,
    required String name,
    required String description,
  }) async {
    await _dio.patch<dynamic>(
      '/api/v1/social/groups/$groupId',
      data: {'name': name, 'description': description},
    );
  }

  Future<void> archiveGroup({required String groupId}) async {
    await _dio.post<dynamic>('/api/v1/social/groups/$groupId/archive');
  }

  Future<void> unarchiveGroup({required String groupId}) async {
    await _dio.post<dynamic>('/api/v1/social/groups/$groupId/unarchive');
  }

  Future<void> leaveGroup({required String groupId}) async {
    await _dio.post<dynamic>('/api/v1/social/groups/$groupId/leave');
  }

  Future<List<GroupActivityItem>> fetchGroupActivity(String groupId) async {
    final response = await _dio.get<dynamic>('/api/v1/social/groups/$groupId/activity');
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => GroupActivityItem(
          eventId: '${json['eventId']}',
          type: '${json['type']}',
          userId: '${json['userId']}',
          displayName: '${json['displayName']}',
          timestamp: DateTime.tryParse('${json['timestamp']}')?.toLocal() ?? DateTime.now(),
        )).toList();
  }

  Future<List<OutgoingGroupInvite>> fetchPendingGroupInvites(String groupId) async {
    final response = await _dio.get<dynamic>('/api/v1/social/groups/$groupId/invites/pending');
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => OutgoingGroupInvite(
          inviteId: '${json['inviteId']}',
          groupId: '${json['groupId']}',
          inviteeUserId: '${json['inviteeUserId']}',
          inviteeName: '${json['inviteeName']}',
          inviteePhone: '${json['inviteePhone']}',
          createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
        )).toList();
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
    await _dio.delete<dynamic>('/api/v1/social/groups/$groupId/members/$userId');
  }

  Future<void> promoteToAdmin({
    required String groupId,
    required String userId,
  }) async {
    await _dio.post<dynamic>('/api/v1/social/groups/$groupId/members/$userId/promote');
  }

  Future<void> demoteToMember({
    required String groupId,
    required String userId,
  }) async {
    await _dio.post<dynamic>('/api/v1/social/groups/$groupId/members/$userId/demote');
  }

  Future<void> nudgePendingMember({
    required String groupId,
    required String userId,
  }) async {
    await _dio.post<dynamic>('/api/v1/social/groups/$groupId/members/$userId/nudge');
  }

  Future<List<GroupInviteInboxItem>> fetchIncomingGroupInvites() async {
    final response = await _dio.get<dynamic>('/api/v1/social/groups/invites/incoming');
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map((json) => GroupInviteInboxItem(
          inviteId: '${json['inviteId']}',
          groupId: '${json['groupId']}',
          groupName: '${json['groupName']}',
          inviterUserId: '${json['inviterUserId']}',
          inviterName: '${json['inviterName']}',
          createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
        )).toList();
  }

  Future<void> respondGroupInvite({
    required String groupId,
    required String inviteId,
    required InviteDecision decision,
  }) async {
    await _dio.post<dynamic>(
      '/api/v1/social/groups/$groupId/invites/$inviteId/respond',
      data: {'status': decision == InviteDecision.accepted ? 'ACCEPTED' : 'DECLINED'},
    );
  }
}
