import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notifications/data/notification_api_repository.dart';
import '../../../../core/network/dio_provider.dart';

class NotificationPreferencesState {
  const NotificationPreferencesState({
    this.notifyJoin = true,
    this.notifyLeaveHost = true,
    this.notifyFillingFast = true,
    this.notifyStarts15 = true,
    this.notifyStarts60 = true,
    this.notifyNewNearby = true,
    this.radiusKm = 5,
    this.interestCategories = 'sports,study',
  });

  final bool notifyJoin;
  final bool notifyLeaveHost;
  final bool notifyFillingFast;
  final bool notifyStarts15;
  final bool notifyStarts60;
  final bool notifyNewNearby;
  final int radiusKm;
  final String interestCategories;

  NotificationPreferencesState copyWith({
    bool? notifyJoin,
    bool? notifyLeaveHost,
    bool? notifyFillingFast,
    bool? notifyStarts15,
    bool? notifyStarts60,
    bool? notifyNewNearby,
    int? radiusKm,
    String? interestCategories,
  }) {
    return NotificationPreferencesState(
      notifyJoin: notifyJoin ?? this.notifyJoin,
      notifyLeaveHost: notifyLeaveHost ?? this.notifyLeaveHost,
      notifyFillingFast: notifyFillingFast ?? this.notifyFillingFast,
      notifyStarts15: notifyStarts15 ?? this.notifyStarts15,
      notifyStarts60: notifyStarts60 ?? this.notifyStarts60,
      notifyNewNearby: notifyNewNearby ?? this.notifyNewNearby,
      radiusKm: radiusKm ?? this.radiusKm,
      interestCategories: interestCategories ?? this.interestCategories,
    );
  }

  factory NotificationPreferencesState.fromDomain(NotificationPreferences domain) {
    return NotificationPreferencesState(
      notifyJoin: domain.notifyJoin,
      notifyLeaveHost: domain.notifyLeaveHost,
      notifyFillingFast: domain.notifyFillingFast,
      notifyStarts15: domain.notifyStarts15,
      notifyStarts60: domain.notifyStarts60,
      notifyNewNearby: domain.notifyNewNearby,
      radiusKm: domain.radiusKm,
      interestCategories: domain.interestCategories,
    );
  }

  NotificationPreferences toDomain() {
    return NotificationPreferences(
      notifyJoin: notifyJoin,
      notifyLeaveHost: notifyLeaveHost,
      notifyFillingFast: notifyFillingFast,
      notifyStarts15: notifyStarts15,
      notifyStarts60: notifyStarts60,
      notifyNewNearby: notifyNewNearby,
      interestCategories: interestCategories,
      radiusKm: radiusKm,
    );
  }
}


class NotificationPreferencesController
    extends StateNotifier<NotificationPreferencesState> {
  NotificationPreferencesController(this._repository) : super(const NotificationPreferencesState()) {
    load();
  }

  final NotificationApiRepository _repository;

  Future<void> load() async {
    try {
      final domain = await _repository.fetchPreferences();
      state = NotificationPreferencesState.fromDomain(domain);
    } catch (_) {}
  }

  Future<void> _update(NotificationPreferencesState next) async {
    final prev = state;
    state = next;
    try {
      final updated = await _repository.updatePreferences(next.toDomain());
      state = NotificationPreferencesState.fromDomain(updated);
    } catch (_) {
      state = prev;
    }
  }

  void setNotifyJoin(bool value) => _update(state.copyWith(notifyJoin: value));
  void setNotifyLeaveHost(bool value) => _update(state.copyWith(notifyLeaveHost: value));
  void setNotifyFillingFast(bool value) => _update(state.copyWith(notifyFillingFast: value));
  void setNotifyStarts15(bool value) => _update(state.copyWith(notifyStarts15: value));
  void setNotifyStarts60(bool value) => _update(state.copyWith(notifyStarts60: value));
  void setNotifyNewNearby(bool value) => _update(state.copyWith(notifyNewNearby: value));
  void setRadius(int km) => _update(state.copyWith(radiusKm: km));
}

final notificationPreferencesProvider = StateNotifierProvider<
  NotificationPreferencesController,
  NotificationPreferencesState
>((ref) {
  return NotificationPreferencesController(ref.watch(notificationApiRepositoryProvider));
});
