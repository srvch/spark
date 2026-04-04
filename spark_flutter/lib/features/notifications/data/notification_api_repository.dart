import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';

final notificationApiRepositoryProvider = Provider<NotificationApiRepository>((ref) {
  return NotificationApiRepository(dio: ref.watch(dioProvider));
});

class NotificationApiRepository {
  NotificationApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<SparkNotification>> fetchNotifications({bool unreadOnly = false}) async {
    final response = await _dio.get<dynamic>(
      '/api/v1/notifications',
      queryParameters: {'unreadOnly': unreadOnly},
    );
    final rows = response.data is List ? response.data as List : const [];
    return rows.whereType<Map<String, dynamic>>().map(_fromJson).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _dio.post<void>('/api/v1/notifications/$notificationId/read');
  }

  Future<NotificationPreferences> fetchPreferences() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/notifications/preferences');
    return _prefsFromJson(response.data ?? const {});
  }

  Future<NotificationPreferences> updatePreferences(NotificationPreferences prefs) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/notifications/preferences',
      data: _prefsToJson(prefs),
    );
    return _prefsFromJson(response.data ?? const {});
  }

  SparkNotification _fromJson(Map<String, dynamic> json) {
    return SparkNotification(
      id: '${json['id']}',
      type: '${json['type']}',
      title: '${json['title']}',
      body: '${json['body']}',
      sparkId: json['sparkId'] as String?,
      createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
      readAt: DateTime.tryParse('${json['readAt'] ?? ''}')?.toLocal(),
    );
  }

  NotificationPreferences _prefsFromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      notifyJoin: json['notifyJoin'] == true,
      notifyLeaveHost: json['notifyLeaveHost'] == true,
      notifyFillingFast: json['notifyFillingFast'] == true,
      notifyStarts15: json['notifyStarts15'] == true,
      notifyStarts60: json['notifyStarts60'] == true,
      notifyNewNearby: json['notifyNewNearby'] == true,
      interestCategories: '${json['interestCategories'] ?? ''}',
      radiusKm: (json['radiusKm'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> _prefsToJson(NotificationPreferences prefs) {
    return {
      'notifyJoin': prefs.notifyJoin,
      'notifyLeaveHost': prefs.notifyLeaveHost,
      'notifyFillingFast': prefs.notifyFillingFast,
      'notifyStarts15': prefs.notifyStarts15,
      'notifyStarts60': prefs.notifyStarts60,
      'notifyNewNearby': prefs.notifyNewNearby,
      'interestCategories': prefs.interestCategories,
      'radiusKm': prefs.radiusKm,
    };
  }
}

class SparkNotification {
  const SparkNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.sparkId,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? sparkId;
  final DateTime createdAt;
  final DateTime? readAt;
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.notifyJoin,
    required this.notifyLeaveHost,
    required this.notifyFillingFast,
    required this.notifyStarts15,
    required this.notifyStarts60,
    required this.notifyNewNearby,
    required this.interestCategories,
    required this.radiusKm,
  });

  final bool notifyJoin;
  final bool notifyLeaveHost;
  final bool notifyFillingFast;
  final bool notifyStarts15;
  final bool notifyStarts60;
  final bool notifyNewNearby;
  final String interestCategories;
  final int radiusKm;
}
