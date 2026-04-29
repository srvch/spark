import 'package:dio/dio.dart';

import '../domain/spark.dart';
import '../domain/spark_invite.dart';

class SparkApiRepository {
  SparkApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const int defaultInvitePageSize = 20;

  Future<NearbySparkPage> fetchNearby({
    required double lat,
    required double lng,
    required double radiusKm,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get<dynamic>(
      '/api/v1/sparks/nearby',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        'page': page,
        'size': size,
      },
    );
    final data = response.data;

    if (data is Map<String, dynamic>) {
      final items = (data['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((row) => _fromNearbyJson(row))
          .toList();
      final hasMore = (data['hasMore'] as bool?) ?? false;
      final responsePage = (data['page'] as num?)?.toInt() ?? page;
      return NearbySparkPage(
        items: items,
        page: responsePage,
        hasMore: hasMore,
      );
    }

    final rows = data is List ? data : const [];
    final items = rows
        .whereType<Map<String, dynamic>>()
        .map((row) => _fromNearbyJson(row))
        .toList();
    return NearbySparkPage(
      items: items,
      page: page,
      hasMore: items.length == size,
    );
  }

  Future<Spark> createSpark({
    required SparkCategory category,
    required String title,
    required String? note,
    required String locationName,
    required double latitude,
    required double longitude,
    required DateTime startsAt,
    DateTime? endsAt,
    required int maxSpots,
    SparkVisibility visibility = SparkVisibility.publicSpark,
    List<String> inviteUserIds = const [],
    List<String> circleIds = const [],
    String? recurrenceType,
    int? recurrenceDayOfWeek,
    String? recurrenceTime,
    DateTime? recurrenceEndDate,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sparks',
      data: {
        'category': category.name,
        'title': title,
        'note': note,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'maxSpots': maxSpots,
        'visibility': _toApiVisibility(visibility),
        if (inviteUserIds.isNotEmpty) 'inviteUserIds': inviteUserIds,
        if (circleIds.isNotEmpty) 'circleIds': circleIds,
        if (recurrenceType != null) 'recurrenceType': recurrenceType,
        if (recurrenceDayOfWeek != null) 'recurrenceDayOfWeek': recurrenceDayOfWeek,
        if (recurrenceTime != null) 'recurrenceTime': recurrenceTime,
        if (recurrenceEndDate != null)
          'recurrenceEndDate':
              '${recurrenceEndDate.year}-${recurrenceEndDate.month.toString().padLeft(2, '0')}-${recurrenceEndDate.day.toString().padLeft(2, '0')}',
      },
    );
    return _fromSparkJson(response.data ?? const {}, fallbackDistanceKm: 0.3);
  }

  Future<Spark> updateSpark({
    required String sparkId,
    required SparkCategory category,
    required String title,
    required String? note,
    required String locationName,
    required double latitude,
    required double longitude,
    required DateTime startsAt,
    DateTime? endsAt,
    required int maxSpots,
    SparkVisibility visibility = SparkVisibility.publicSpark,
    List<String> inviteUserIds = const [],
    List<String> circleIds = const [],
    String? recurrenceType,
    int? recurrenceDayOfWeek,
    String? recurrenceTime,
    DateTime? recurrenceEndDate,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/sparks/$sparkId',
      data: {
        'category': category.name,
        'title': title,
        'note': note,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'maxSpots': maxSpots,
        'visibility': _toApiVisibility(visibility),
        if (inviteUserIds.isNotEmpty) 'inviteUserIds': inviteUserIds,
        if (circleIds.isNotEmpty) 'circleIds': circleIds,
        if (recurrenceType != null) 'recurrenceType': recurrenceType,
        if (recurrenceDayOfWeek != null) 'recurrenceDayOfWeek': recurrenceDayOfWeek,
        if (recurrenceTime != null) 'recurrenceTime': recurrenceTime,
        if (recurrenceEndDate != null)
          'recurrenceEndDate':
              '${recurrenceEndDate.year}-${recurrenceEndDate.month.toString().padLeft(2, '0')}-${recurrenceEndDate.day.toString().padLeft(2, '0')}',
      },
    );
    return _fromSparkJson(response.data ?? const {}, fallbackDistanceKm: 0.3);
  }

  Future<Spark> joinSpark({
    required String sparkId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sparks/$sparkId/join',
    );
    return _fromSparkJson(response.data ?? const {}, fallbackDistanceKm: 0.3);
  }

  Future<Spark> leaveSpark({
    required String sparkId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sparks/$sparkId/leave',
    );
    return _fromSparkJson(response.data ?? const {}, fallbackDistanceKm: 0.3);
  }

  Future<void> cancelSpark({
    required String sparkId,
  }) async {
    await _dio.delete('/api/v1/sparks/$sparkId');
  }

  Future<SparkInvitePage> fetchInvites({
    int page = 0,
    int size = defaultInvitePageSize,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/sparks/invites',
      queryParameters: {
        'page': page,
        'size': size,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_fromInviteJson)
        .toList();
    final responsePage = (data['page'] as num?)?.toInt() ?? page;
    final hasMore = (data['hasMore'] as bool?) ?? false;
    return SparkInvitePage(
      items: items,
      page: responsePage,
      hasMore: hasMore,
    );
  }

  Future<SparkInviteStatus> respondToInvite({
    required String sparkId,
    required String inviteId,
    required SparkInviteStatus status,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sparks/$sparkId/invite/$inviteId/respond',
      data: {'status': _toApiInviteStatus(status)},
    );
    final data = response.data ?? const <String, dynamic>{};
    final raw = (data['status'] ?? '').toString();
    if (raw.isEmpty) return status;
    return _toInviteStatus(raw);
  }

  Future<Spark> fetchSparkDetail(String sparkId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/sparks/$sparkId');
    return _fromSparkJson(response.data ?? const {}, fallbackDistanceKm: 0.1);
  }

  Future<List<String>> fetchParticipants(String sparkId) async {
    final response = await _dio.get<dynamic>('/api/v1/sparks/$sparkId/participants');
    final rows = response.data is List ? response.data as List : const [];
    return rows.map((e) => '$e').toList();
  }

  Spark _fromNearbyJson(Map<String, dynamic> json) {
    return _buildSpark(
      id: '${json['id']}',
      categoryRaw: '${json['category']}',
      title: '${json['title']}',
      startsAtRaw: '${json['startsAt']}',
      distanceKm: ((json['distanceKm'] ?? 0) as num).toDouble(),
      spotsLeft: (json['spotsLeft'] as num?)?.toInt() ?? 0,
      maxSpots: (json['maxSpots'] as num?)?.toInt() ?? 0,
      locationName: '${json['locationName']}',
      hostUserId: '${json['hostUserId']}',
      hostPhoneNumber: _nullableString(json['hostPhoneNumber']),
      joinedCount: (json['joinedCount'] as num?)?.toInt() ?? 0,
      note: null,
      visibilityRaw: _nullableString(json['visibility']),
      hideHostPhoneNumber: json['hideHostPhoneNumber'] == true,
      json: json,
    );
  }

  Spark _fromSparkJson(Map<String, dynamic> json, {double fallbackDistanceKm = 0.0}) {
    return _buildSpark(
      id: '${json['id']}',
      categoryRaw: '${json['category']}',
      title: '${json['title']}',
      startsAtRaw: '${json['startsAt']}',
      distanceKm: fallbackDistanceKm,
      spotsLeft: (json['spotsLeft'] as num?)?.toInt() ?? 0,
      maxSpots: (json['maxSpots'] as num?)?.toInt() ?? 0,
      locationName: '${json['locationName']}',
      hostUserId: '${json['hostUserId']}',
      hostPhoneNumber: _nullableString(json['hostPhoneNumber']),
      joinedCount: (json['joinedCount'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      visibilityRaw: _nullableString(json['visibility']),
      hideHostPhoneNumber: json['hideHostPhoneNumber'] == true,
      json: json,
    );
  }

  Spark _buildSpark({
    required String id,
    required String categoryRaw,
    required String title,
    required String startsAtRaw,
    required double distanceKm,
    required int spotsLeft,
    required int maxSpots,
    required String locationName,
    required String hostUserId,
    required String? hostPhoneNumber,
    required int joinedCount,
    required String? note,
    required String? visibilityRaw,
    required bool hideHostPhoneNumber,
    Map<String, dynamic>? json,
  }) {
    final startsAt = DateTime.tryParse(startsAtRaw)?.toLocal() ?? DateTime.now();
    final diffMinutes = startsAt.difference(DateTime.now()).inMinutes.clamp(0, 24 * 60);
    final category = SparkCategory.fromString(categoryRaw);
    return Spark(
      id: id,
      category: category,
      title: title,
      startsInMinutes: diffMinutes,
      timeLabel: diffMinutes == 0 ? 'Starts now' : 'Starts in $diffMinutes min',
      distanceKm: distanceKm,
      distanceLabel: _distanceLabel(distanceKm),
      spotsLeft: spotsLeft,
      maxSpots: maxSpots == 0 ? 1 : maxSpots,
      location: locationName,
      createdBy: hostUserId,
      participants: const [],
      hostPhoneNumber: hostPhoneNumber,
      hideHostPhoneNumber: hideHostPhoneNumber,
      note: note,
      visibility: _toVisibility(visibilityRaw),
      shareUrl: json != null ? _nullableString(json['shareUrl'] as String?) : null,
      recurrenceType: json != null ? _nullableString(json['recurrenceType'] as String?) : null,
    );
  }

  SparkInvite _fromInviteJson(Map<String, dynamic> json) {
    return SparkInvite(
      inviteId: '${json['inviteId']}',
      sparkId: '${json['sparkId']}',
      fromUserId: '${json['fromUserId']}',
      status: _toInviteStatus('${json['inviteStatus']}'),
      invitedAt: DateTime.tryParse('${json['invitedAt']}')?.toLocal() ?? DateTime.now(),
      actedAt: DateTime.tryParse('${json['actedAt'] ?? ''}')?.toLocal(),
      title: '${json['title']}',
      category: SparkCategory.fromString('${json['category']}'),
      locationName: '${json['locationName']}',
      startsAt: DateTime.tryParse('${json['startsAt'] ?? ''}')?.toLocal(),
      sparkStatus: '${json['sparkStatus']}',
    );
  }

  // Removed: _toCategory() — use SparkCategory.fromString() from the domain model instead

  SparkInviteStatus _toInviteStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'IN':
        return SparkInviteStatus.inStatus;
      case 'MAYBE':
        return SparkInviteStatus.maybe;
      case 'DECLINED':
        return SparkInviteStatus.declined;
      case 'PENDING':
      default:
        return SparkInviteStatus.pending;
    }
  }

  String _toApiInviteStatus(SparkInviteStatus status) {
    switch (status) {
      case SparkInviteStatus.inStatus:
        return 'IN';
      case SparkInviteStatus.maybe:
        return 'MAYBE';
      case SparkInviteStatus.declined:
        return 'DECLINED';
      case SparkInviteStatus.pending:
        return 'PENDING';
    }
  }

  SparkVisibility _toVisibility(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'CIRCLE':
        return SparkVisibility.circle;
      case 'INVITE':
        return SparkVisibility.invite;
      case 'PUBLIC':
      default:
        return SparkVisibility.publicSpark;
    }
  }

  String _toApiVisibility(SparkVisibility visibility) {
    switch (visibility) {
      case SparkVisibility.publicSpark:
        return 'PUBLIC';
      case SparkVisibility.circle:
        return 'CIRCLE';
      case SparkVisibility.invite:
        return 'INVITE';
    }
  }

  String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  String _distanceLabel(double distanceKm) {
    if (distanceKm <= 0) return 'Nearby';
    if (distanceKm < 1) return '${(distanceKm * 1000).round()}m away';
    return '${distanceKm.toStringAsFixed(1)}km away';
  }
}

class NearbySparkPage {
  const NearbySparkPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<Spark> items;
  final int page;
  final bool hasMore;
}
