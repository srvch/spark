enum InviteDecision { accepted, declined }

class FriendUser {
  const FriendUser({
    required this.userId,
    required this.displayName,
    required this.phoneNumber,
  });

  final String userId;
  final String displayName;
  final String phoneNumber;
}

class IncomingFriendRequest {
  const IncomingFriendRequest({
    required this.requestId,
    required this.fromUserId,
    required this.displayName,
    required this.phoneNumber,
    required this.createdAt,
  });

  final String requestId;
  final String fromUserId;
  final String displayName;
  final String phoneNumber;
  final DateTime createdAt;
}

class SparkGroup {
  const SparkGroup({
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

  bool get isOwner => myRole.toUpperCase() == 'OWNER';
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

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.phoneNumber,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String phoneNumber;
  final String role;

  bool get isOwner => role.toUpperCase() == 'OWNER';
}

class GroupDetail {
  const GroupDetail({
    required this.groupId,
    required this.name,
    required this.description,
    required this.ownerUserId,
    required this.myRole,
    required this.members,
  });

  final String groupId;
  final String name;
  final String description;
  final String ownerUserId;
  final String myRole;
  final List<GroupMember> members;

  bool get isOwner => myRole.toUpperCase() == 'OWNER';
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

// Keep backward-compat alias
typedef FriendRequestDecision = InviteDecision;
