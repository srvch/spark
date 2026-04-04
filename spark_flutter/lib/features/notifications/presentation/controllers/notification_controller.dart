import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/notification_api_repository.dart';

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, AsyncValue<List<SparkNotification>>>((ref) {
  return NotificationController(ref.watch(notificationApiRepositoryProvider));
});

class NotificationController extends StateNotifier<AsyncValue<List<SparkNotification>>> {
  NotificationController(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final NotificationApiRepository _repository;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final notifications = await _repository.fetchNotifications();
      state = AsyncValue.data(notifications);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(String id) async {
    final prev = state.valueOrNull ?? [];
    try {
      await _repository.markAsRead(id);
      state = AsyncValue.data(
        prev.map((n) => n.id == id ? _markReadInModel(n) : n).toList(),
      );
    } catch (_) {}
  }

  SparkNotification _markReadInModel(SparkNotification n) {
    return SparkNotification(
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      sparkId: n.sparkId,
      createdAt: n.createdAt,
      readAt: DateTime.now(),
    );
  }
}
