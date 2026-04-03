import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../spark/domain/spark.dart';

class NotificationPreferencesState {
  const NotificationPreferencesState({
    this.notifyStartsSoon = true,
    this.notifyFillingFast = true,
    this.notifyFriendRequest = true,
    this.notifyWaitlist = true,
    this.notifyReminder = true,
    this.radiusKm = 5,
    this.interests = const {
      SparkCategory.sports,
      SparkCategory.study,
    },
  });

  final bool notifyStartsSoon;
  final bool notifyFillingFast;
  final bool notifyFriendRequest;
  final bool notifyWaitlist;
  final bool notifyReminder;
  final int radiusKm;
  final Set<SparkCategory> interests;

  NotificationPreferencesState copyWith({
    bool? notifyStartsSoon,
    bool? notifyFillingFast,
    bool? notifyFriendRequest,
    bool? notifyWaitlist,
    bool? notifyReminder,
    int? radiusKm,
    Set<SparkCategory>? interests,
  }) {
    return NotificationPreferencesState(
      notifyStartsSoon: notifyStartsSoon ?? this.notifyStartsSoon,
      notifyFillingFast: notifyFillingFast ?? this.notifyFillingFast,
      notifyFriendRequest: notifyFriendRequest ?? this.notifyFriendRequest,
      notifyWaitlist: notifyWaitlist ?? this.notifyWaitlist,
      notifyReminder: notifyReminder ?? this.notifyReminder,
      radiusKm: radiusKm ?? this.radiusKm,
      interests: interests ?? this.interests,
    );
  }
}

class NotificationPreferencesController
    extends StateNotifier<NotificationPreferencesState> {
  NotificationPreferencesController() : super(const NotificationPreferencesState());

  void setStartsSoon(bool value) {
    state = state.copyWith(notifyStartsSoon: value);
  }

  void setFillingFast(bool value) {
    state = state.copyWith(notifyFillingFast: value);
  }

  void setFriendRequest(bool value) {
    state = state.copyWith(notifyFriendRequest: value);
  }

  void setWaitlist(bool value) {
    state = state.copyWith(notifyWaitlist: value);
  }

  void setReminder(bool value) {
    state = state.copyWith(notifyReminder: value);
  }

  void setRadius(int km) {
    state = state.copyWith(radiusKm: km);
  }

  void toggleInterest(SparkCategory category) {
    final next = {...state.interests};
    if (next.contains(category)) {
      if (next.length == 1) return;
      next.remove(category);
    } else {
      next.add(category);
    }
    state = state.copyWith(interests: next);
  }
}

final notificationPreferencesProvider = StateNotifierProvider<
  NotificationPreferencesController,
  NotificationPreferencesState
>((ref) {
  return NotificationPreferencesController();
});
