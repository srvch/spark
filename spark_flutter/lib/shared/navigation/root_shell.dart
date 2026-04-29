import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/auth/auth_state.dart';
import '../../features/auth/presentation/screens/mandatory_profile_screen.dart';
import '../../features/chat/presentation/screens/chat_inbox_screen.dart';
import '../../features/spark/domain/spark_invite.dart';
import '../../features/spark/presentation/controllers/spark_controller.dart';
import '../../features/spark/presentation/screens/create_spark_screen.dart';
import '../../features/spark/presentation/screens/discover_screen.dart';
import '../../features/spark/presentation/screens/spark_detail_screen.dart';

final bottomTabProvider = StateProvider<int>((ref) => 0);

void backOrGoDiscover(BuildContext context, WidgetRef ref) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  ref.read(bottomTabProvider.notifier).state = 0;
}

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final shouldBlockForProfile =
        session != null &&
        !session.isGuestShowcase &&
        !session.hasCompletedMandatoryProfile;
    if (shouldBlockForProfile) {
      return const MandatoryProfileScreen();
    }

    final tab = ref.watch(bottomTabProvider);
    final activeTab = tab > 2 ? 2 : tab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackground = isDark ? const Color(0xFF151B2F) : Colors.white;

    // Handle deep links — navigate to spark detail when a link arrives
    ref.listen<String?>(pendingDeepLinkSparkIdProvider, (_, sparkId) {
      if (sparkId == null) return;
      ref.read(pendingDeepLinkSparkIdProvider.notifier).state = null;

      // Fetch and show the spark
      ref.read(sparkDataControllerProvider).fetchSparkDetail(sparkId);

      // Switch to Explore tab and push detail once spark is in state
      ref.read(bottomTabProvider.notifier).state = 0;

      // Small delay to let the spark load into the provider
      Future.delayed(const Duration(milliseconds: 400), () {
        final sparks = ref.read(allSparksProvider);
        final spark = sparks.where((s) => s.id == sparkId).firstOrNull;
        if (spark != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SparkDetailScreen(spark: spark)),
          );
        }
      });
    });

    final joinedCount = ref.watch(joinedSparksProvider).length;
    final createdCount = ref.watch(myCreatedSparksProvider).length;
    final chatCount = joinedCount + createdCount;
    final seenCount = ref.watch(seenChatCountProvider);
    final pendingInvitesCount =
        ref
            .watch(sparkInvitesProvider)
            .where((invite) => invite.status == SparkInviteStatus.pending)
            .length;
    final hasUnreadChat = chatCount > seenCount || pendingInvitesCount > 0;
    final screens = const [
      DiscoverScreen(),
      CreateSparkScreen(),
      ChatInboxScreen(),
    ];

    return Scaffold(
      extendBody: false,
      body: screens[activeTab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBackground,
          border: Border(
            top: BorderSide(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.08,
              ),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                _NavItem(
                  label: 'Explore',
                  icon: CupertinoIcons.compass,
                  activeIcon: CupertinoIcons.compass_fill,
                  selected: activeTab == 0,
                  onTap: () => ref.read(bottomTabProvider.notifier).state = 0,
                ),
                _CreateNavItem(
                  selected: activeTab == 1,
                  onTap: () => ref.read(bottomTabProvider.notifier).state = 1,
                ),
                _NavItem(
                  label: 'Chat',
                  icon: CupertinoIcons.bubble_left,
                  activeIcon: CupertinoIcons.bubble_left_fill,
                  selected: activeTab == 2,
                  showBadge: hasUnreadChat && activeTab != 2,
                  onTap: () {
                    ref.read(bottomTabProvider.notifier).state = 2;
                    ref.read(seenChatCountProvider.notifier).state = chatCount;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateNavItem extends StatelessWidget {
  const _CreateNavItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      selected
                          ? [AppColors.accent, AppColors.accentLight]
                          : [
                            AppColors.accent.withValues(alpha: 0.1),
                            AppColors.accent.withValues(alpha: 0.05),
                          ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(
                      alpha: selected ? 0.3 : 0,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.add,
                size: 24,
                color: selected ? Colors.white : AppColors.accent,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                fontFamily: 'Manrope',
                letterSpacing: selected ? 0.1 : 0,
              ),
              child: const Text('Create'),
            ),
          ],
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
    this.showBadge = false,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool showBadge;

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
                color:
                    selected
                        ? (isDark
                            ? AppColors.darkAccent.withValues(alpha: 0.15)
                            : AppColors.accent.withValues(alpha: 0.08))
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      selected ? activeIcon : icon,
                      key: ValueKey(selected),
                      size: 22,
                      color: selected ? activeColor : inactiveColor,
                    ),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -3,
                      right: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
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
