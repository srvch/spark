import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    final screens = const [
      DiscoverScreen(),
      CreateSparkScreen(),
      ChatInboxScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: screens[tab],
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF2D333B) : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  label: 'Discover',
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  selected: tab == 0,
                  onTap: () =>
                      ref.read(bottomTabProvider.notifier).state = 0,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'Create',
                  icon: Icons.add_circle_outline,
                  activeIcon: Icons.add_circle,
                  selected: tab == 1,
                  onTap: () =>
                      ref.read(bottomTabProvider.notifier).state = 1,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  selected: tab == 2,
                  onTap: () =>
                      ref.read(bottomTabProvider.notifier).state = 2,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'Profile',
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  selected: tab == 3,
                  onTap: () =>
                      ref.read(bottomTabProvider.notifier).state = 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
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
    final accent = Theme.of(context).colorScheme.primary;
    final inactive = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8B949E)
        : const Color(0xFF6B7280);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                size: 20,
                color: selected ? accent : inactive,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? accent : inactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
