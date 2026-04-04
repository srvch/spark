import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

class SafetyApiRepository {
  SafetyApiRepository({required Dio dio}) : _dio = dio;
  final Dio _dio;

  Future<List<String>> fetchGuidelines() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/safety/guidelines');
    final list = response.data?['guidelines'] as List<dynamic>? ?? const [];
    return list.map((e) => '$e').toList();
  }

  Future<SosResponse> triggerSos({
    required String sparkId,
    required String locationName,
    required String note,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/safety/sos',
      data: {
        'sparkId': sparkId,
        'locationName': locationName,
        'note': note,
      },
    );
    final data = response.data ?? const {};
    return SosResponse(
      alertId: '${data['alertId']}',
      status: '${data['status']}',
      createdAt: DateTime.tryParse('${data['createdAt']}')?.toLocal() ?? DateTime.now(),
    );
  }
}

class SosResponse {
  const SosResponse({
    required this.alertId,
    required this.status,
    required this.createdAt,
  });
  final String alertId;
  final String status;
  final DateTime createdAt;
}

final safetyApiRepositoryProvider = Provider<SafetyApiRepository>((ref) {
  return SafetyApiRepository(dio: ref.watch(dioProvider));
});
