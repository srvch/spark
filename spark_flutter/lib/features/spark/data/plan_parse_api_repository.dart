import 'package:dio/dio.dart';

import '../domain/spark.dart';

class PlanParseApiRepository {
  PlanParseApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<PlanParseResult> parsePlan({
    required String input,
    required String locationHint,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/ai/parse-plan',
      data: {
        'input': input,
        'locationHint': locationHint,
      },
    );
    final json = response.data ?? const {};
    final categoryRaw = '${json['category']}'.toLowerCase();
    final category = switch (categoryRaw) {
      'sports' => SparkCategory.sports,
      'study' => SparkCategory.study,
      'ride' => SparkCategory.ride,
      'events' => SparkCategory.events,
      'hangout' => SparkCategory.hangout,
      _ => SparkCategory.sports,
    };
    final startsAt = DateTime.tryParse('${json['startsAt']}')?.toLocal();

    return PlanParseResult(
      title: ('${json['title']}'.trim().isEmpty ? input : '${json['title']}').trim(),
      category: category,
      locationName: ('${json['locationName']}'.trim().isEmpty
              ? locationHint
              : '${json['locationName']}')
          .trim(),
      startsAt: startsAt,
      maxSpots: ((json['maxSpots'] as num?)?.toInt() ?? 4).clamp(1, 20),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      source: '${json['source'] ?? 'heuristic'}',
    );
  }
}

class PlanParseResult {
  const PlanParseResult({
    required this.title,
    required this.category,
    required this.locationName,
    required this.startsAt,
    required this.maxSpots,
    required this.confidence,
    required this.source,
  });

  final String title;
  final SparkCategory category;
  final String locationName;
  final DateTime? startsAt;
  final int maxSpots;
  final double confidence;
  final String source;
}
