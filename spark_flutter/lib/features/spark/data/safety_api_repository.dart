import 'package:dio/dio.dart';

class SafetyApiRepository {
  SafetyApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<String>> fetchGuidelines() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/safety/guidelines');
    final data = response.data ?? const {};
    final list = (data['guidelines'] as List<dynamic>? ?? const [])
        .map((e) => '$e')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return list;
  }

  Future<void> triggerSos({
    required String sparkId,
    required String locationName,
    String? note,
  }) async {
    await _dio.post<void>(
      '/api/v1/safety/sos',
      data: {
        'sparkId': sparkId,
        'locationName': locationName,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
      },
    );
  }
}
