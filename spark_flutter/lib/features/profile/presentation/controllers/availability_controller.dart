import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A slot is encoded as "$weekday-$period" where:
///   weekday: 1 (Mon) – 7 (Sun)
///   period:  0 (Morning) | 1 (Afternoon) | 2 (Evening)
final availabilityProvider = StateProvider<Set<String>>((ref) => const {});

class AvailabilityHelper {
  static const List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> periods = ['Morning', 'Afternoon', 'Evening'];

  static String key(int day, int period) => '$day-$period';

  static bool has(Set<String> set, int day, int period) =>
      set.contains(key(day, period));

  static Set<String> toggle(Set<String> set, int day, int period) {
    final k = key(day, period);
    final next = {...set};
    if (next.contains(k)) {
      next.remove(k);
    } else {
      next.add(k);
    }
    return next;
  }

  static String summaryLabel(Set<String> set) {
    if (set.isEmpty) return 'Not set';
    final dayCount = <int>{};
    for (final k in set) {
      dayCount.add(int.parse(k.split('-').first));
    }
    if (dayCount.length == 7) return 'Every day';
    if (dayCount.containsAll([6, 7]) && dayCount.length == 2) return 'Weekends';
    if (dayCount.containsAll([1, 2, 3, 4, 5]) && dayCount.length == 5) return 'Weekdays';
    return '${set.length} slot${set.length == 1 ? '' : 's'} set';
  }
}
