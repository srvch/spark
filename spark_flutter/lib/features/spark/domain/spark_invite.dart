import 'spark.dart';

enum SparkInviteStatus {
  pending,
  inStatus,
  maybe,
  declined,
}

class SparkInvite {
  const SparkInvite({
    required this.inviteId,
    required this.sparkId,
    required this.fromUserId,
    required this.status,
    required this.invitedAt,
    this.actedAt,
    required this.title,
    required this.category,
    required this.locationName,
    required this.startsAt,
    required this.sparkStatus,
  });

  final String inviteId;
  final String sparkId;
  final String fromUserId;
  final SparkInviteStatus status;
  final DateTime invitedAt;
  final DateTime? actedAt;
  final String title;
  final SparkCategory category;
  final String locationName;
  final DateTime? startsAt;
  final String sparkStatus;

  SparkInvite copyWith({
    SparkInviteStatus? status,
    DateTime? actedAt,
  }) {
    return SparkInvite(
      inviteId: inviteId,
      sparkId: sparkId,
      fromUserId: fromUserId,
      status: status ?? this.status,
      invitedAt: invitedAt,
      actedAt: actedAt ?? this.actedAt,
      title: title,
      category: category,
      locationName: locationName,
      startsAt: startsAt,
      sparkStatus: sparkStatus,
    );
  }
}

class SparkInvitePage {
  const SparkInvitePage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<SparkInvite> items;
  final int page;
  final bool hasMore;
}

