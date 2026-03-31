import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../spark/domain/spark.dart';

class NotificationPreferencesState {
  const NotificationPreferencesState({
    this.notifyStartsSoon = true,
    this.notifyFillingFast = true,
    this.radiusKm = 5,
    this.interests = const {
      SparkCategory.sports,
      SparkCategory.study,
    },
  });

  final bool notifyStartsSoon;
  final bool notifyFillingFast;
  final int radiusKm;
  final Set<SparkCategory> interests;

  NotificationPreferencesState copyWith({
    bool? notifyStartsSoon,
    bool? notifyFillingFast,
    int? radiusKm,
    Set<SparkCategory>? interests,
  }) {
    return NotificationPreferencesState(
      notifyStartsSoon: notifyStartsSoon ?? this.notifyStartsSoon,
      notifyFillingFast: notifyFillingFast ?? this.notifyFillingFast,
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
