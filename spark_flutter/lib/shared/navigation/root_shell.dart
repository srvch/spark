import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/chat/presentation/screens/chat_inbox_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/spark/presentation/screens/create_spark_screen.dart';
import '../../features/spark/presentation/screens/discover_screen.dart';

final bottomTabProvider = StateProvider<int>((ref) => 0);

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(bottomTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : Colors.white;

    final screens = const [
      DiscoverScreen(),
      CreateSparkScreen(),
      ChatInboxScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: screens[tab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  label: 'Discover',
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  selected: tab == 0,
                  onTap: () =>
                      ref.read(bottomTabProvider.notifier).state = 0,
                ),
                _NavItem(
                  label: 'Create',
                  icon: Icons.add_circle_outline_rounded,
                  activeIcon: Icons.add_circle_rounded,
                  selected: tab == 1,
                  onTap: () =>
                      ref.read(bottomTabProvider.notifier).state = 1,
                ),
                _NavItem(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  selected: tab == 2,
                  onTap: () =>
                      ref.read(bottomTabProvider.notifier).state = 2,
                ),
                _NavItem(
                  label: 'Profile',
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  selected: tab == 3,
                  onTap: () =>
                      ref.read(bottomTabProvider.notifier).state = 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = AppColors.accent;
    final inactiveColor =
        isDark ? AppColors.darkTextSecondary : AppColors.darkTextSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark
                        ? AppColors.darkAccent.withValues(alpha: 0.15)
                        : AppColors.accent.withValues(alpha: 0.08))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? activeColor : inactiveColor,
                letterSpacing: selected ? 0.2 : 0,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
