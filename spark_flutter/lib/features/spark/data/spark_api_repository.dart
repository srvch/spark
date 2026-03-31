import 'package:dio/dio.dart';

import '../domain/spark.dart';

class SparkApiRepository {
  SparkApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

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
  }) {
    final startsAt = DateTime.tryParse(startsAtRaw)?.toLocal() ?? DateTime.now();
    final diffMinutes = startsAt.difference(DateTime.now()).inMinutes.clamp(0, 24 * 60);
    final category = switch (categoryRaw.toLowerCase()) {
      'sports' => SparkCategory.sports,
      'study' => SparkCategory.study,
      'ride' => SparkCategory.ride,
      'events' => SparkCategory.events,
      'hangout' => SparkCategory.hangout,
      _ => SparkCategory.events,
    };
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
      participants: _mockParticipants(joinedCount),
      hostPhoneNumber: hostPhoneNumber,
      note: note,
    );
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

  List<String> _mockParticipants(int joinedCount) {
    const pool = ['AA', 'RK', 'SN', 'VK', 'TJ', 'PS', 'MD', 'AN'];
    if (joinedCount <= 0) return const [];
    final count = joinedCount > pool.length ? pool.length : joinedCount;
    return pool.take(count).toList();
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
