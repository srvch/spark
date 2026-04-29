import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    required this.timestamp,
    this.properties = const <String, Object?>{},
  });

  final String name;
  final DateTime timestamp;
  final Map<String, Object?> properties;
}

class AnalyticsService {
  final List<AnalyticsEvent> _events = <AnalyticsEvent>[];

  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  void track(
    String name, {
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    final event = AnalyticsEvent(
      name: name,
      timestamp: DateTime.now(),
      properties: properties,
    );
    _events.add(event);
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});
