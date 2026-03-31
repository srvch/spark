import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/presentation/screens/chat_inbox_screen.dart';
import '../../features/spark/presentation/screens/create_spark_screen.dart';
import '../../features/spark/presentation/screens/discover_screen.dart';

final bottomTabProvider = StateProvider<int>((ref) => 0);

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(bottomTabProvider);

    final screens = const [
      DiscoverScreen(),
      CreateSparkScreen(),
      ChatInboxScreen(),
    ];

    return Scaffold(
      body: screens[tab],
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  label: 'Discover',
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  selected: tab == 0,
                  onTap: () => ref.read(bottomTabProvider.notifier).state = 0,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'Create',
                  icon: Icons.add_circle_outline,
                  activeIcon: Icons.add_circle,
                  selected: tab == 1,
                  onTap: () => ref.read(bottomTabProvider.notifier).state = 1,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  selected: tab == 2,
                  onTap: () => ref.read(bottomTabProvider.notifier).state = 2,
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? activeIcon : icon,
            size: 20,
            color: selected ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
