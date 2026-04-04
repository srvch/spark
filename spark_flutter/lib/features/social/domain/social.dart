enum InviteDecision { accepted, declined }

enum FriendSort { recent, alphabetical }

enum GroupSort { recent, alphabetical, ownerFirst }

class FriendUser {
  const FriendUser({
    required this.userId,
    required this.displayName,
    required this.phoneNumber,
    this.availabilityStatus = 'NONE',
    this.hidePhoneNumber = false,
  });

  final String userId;
  final String displayName;
  final String phoneNumber;
  final String availabilityStatus;
  final bool hidePhoneNumber;

  bool get isAvailable => availabilityStatus == 'OPEN';
}

class IncomingFriendRequest {
  const IncomingFriendRequest({
    required this.requestId,
    required this.fromUserId,
    required this.displayName,
    required this.phoneNumber,
    required this.createdAt,
    this.message,
    this.hidePhoneNumber = false,
  });

  final String requestId;
  final String fromUserId;
  final String displayName;
  final String phoneNumber;
  final DateTime createdAt;
  final String? message;
  final bool hidePhoneNumber;
}

class OutgoingFriendRequest {
  const OutgoingFriendRequest({
    required this.requestId,
    required this.toUserId,
    required this.displayName,
    required this.phoneNumber,
    required this.createdAt,
    this.message,
    this.hidePhoneNumber = false,
  });

  final String requestId;
  final String toUserId;
  final String displayName;
  final String phoneNumber;
  final DateTime createdAt;
  final String? message;
  final bool hidePhoneNumber;
}

class FriendSuggestion {
  const FriendSuggestion({
    required this.userId,
    required this.displayName,
    required this.phoneNumber,
    required this.mutualGroupCount,
    this.hidePhoneNumber = false,
  });

  final String userId;
  final String displayName;
  final String phoneNumber;
  final int mutualGroupCount;
  final bool hidePhoneNumber;
}

class MatchedContact {
  const MatchedContact({
    required this.userId,
    required this.displayName,
    required this.phoneNumber,
    required this.alreadyFriend,
    this.hidePhoneNumber = false,
  });

  final String userId;
  final String displayName;
  final String phoneNumber;
  final bool alreadyFriend;
  final bool hidePhoneNumber;
}

class SparkGroup {
  const SparkGroup({
    required this.groupId,
    required this.name,
    required this.description,
    required this.ownerUserId,
    required this.myRole,
    required this.memberCount,
    this.archived = false,
  });

  final String groupId;
  final String name;
  final String description;
  final String ownerUserId;
  final String myRole;
  final int memberCount;
  final bool archived;

  bool get isOwner => myRole.toUpperCase() == 'OWNER';
  bool get isAdmin => myRole.toUpperCase() == 'ADMIN';
  bool get canEdit => isOwner || isAdmin;
}

class GroupInviteInboxItem {
  const GroupInviteInboxItem({
    required this.inviteId,
    required this.groupId,
    required this.groupName,
    required this.inviterUserId,
    required this.inviterName,
    required this.createdAt,
  });

  final String inviteId;
  final String groupId;
  final String groupName;
  final String inviterUserId;
  final String inviterName;
  final DateTime createdAt;
}

class OutgoingGroupInvite {
  const OutgoingGroupInvite({
    required this.inviteId,
    required this.groupId,
    required this.inviteeUserId,
    required this.inviteeName,
    required this.inviteePhone,
    required this.createdAt,
  });

  final String inviteId;
  final String groupId;
  final String inviteeUserId;
  final String inviteeName;
  final String inviteePhone;
  final DateTime createdAt;
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.phoneNumber,
    required this.role,
    this.hidePhoneNumber = false,
  });

  final String userId;
  final String displayName;
  final String phoneNumber;
  final String role;
  final bool hidePhoneNumber;

  bool get isOwner => role.toUpperCase() == 'OWNER';
  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get canBePromoted => role.toUpperCase() == 'MEMBER';
  bool get canBeDemoted => role.toUpperCase() == 'ADMIN';
}

class GroupDetail {
  const GroupDetail({
    required this.groupId,
    required this.name,
    required this.description,
    required this.ownerUserId,
    required this.myRole,
    required this.members,
    this.archived = false,
  });

  final String groupId;
  final String name;
  final String description;
  final String ownerUserId;
  final String myRole;
  final List<GroupMember> members;
  final bool archived;

  bool get isOwner => myRole.toUpperCase() == 'OWNER';
  bool get isAdmin => myRole.toUpperCase() == 'ADMIN';
  bool get canEdit => isOwner || isAdmin;
}

class GroupSummary {
  const GroupSummary({
    required this.groupId,
    required this.name,
    required this.description,
    required this.ownerUserId,
    required this.myRole,
    required this.memberCount,
  });

  final String groupId;
  final String name;
  final String description;
  final String ownerUserId;
  final String myRole;
  final int memberCount;
}

class GroupActivityItem {
  const GroupActivityItem({
    required this.eventId,
    required this.type,
    required this.userId,
    required this.displayName,
    required this.timestamp,
  });

  final String eventId;
  final String type;
  final String userId;
  final String displayName;
  final DateTime timestamp;

  bool get isSpark => type == 'spark';
  bool get isJoin => type == 'join';
}

// Keep backward-compat alias
typedef FriendRequestDecision = InviteDecision;
