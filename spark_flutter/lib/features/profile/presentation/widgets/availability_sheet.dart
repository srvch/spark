import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/availability_controller.dart';

void showAvailabilitySheet(BuildContext context) {
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: const _AvailabilitySheet(),
    ),
  );
}

class _AvailabilitySheet extends ConsumerWidget {
  const _AvailabilitySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(availabilityProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'When are you free?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Friends can see your open windows to plan around you.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(7, (dayIdx) {
            final day = dayIdx + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      AvailabilityHelper.days[dayIdx],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: List.generate(3, (period) {
                        final active = AvailabilityHelper.has(slots, day, period);
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: period < 2 ? 6 : 0),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref.read(availabilityProvider.notifier).state =
                                    AvailabilityHelper.toggle(slots, day, period);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.accent
                                      : AppColors.pillSurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _periodLabel(period),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(availabilityProvider.notifier).state = const {};
                },
                child: const Text(
                  'Clear all',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _periodLabel(int period) => switch (period) {
    0 => 'Morning',
    1 => 'Afternoon',
    _ => 'Evening',
  };
}
