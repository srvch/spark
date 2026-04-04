import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../domain/social.dart';
import '../controllers/social_controller.dart';
import 'qr_code_screen.dart';

class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({super.key, required this.friend});
  final FriendUser friend;

  @override
  ConsumerState<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen> {
  bool _unfriending = false;
  bool _blocking = false;

  Future<void> _unfriend() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(widget.friend.displayName),
        message: const Text('Remove this person from your friends?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove friend'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _unfriending = true);
    try {
      await ref.read(socialControllerProvider).unfriend(userId: widget.friend.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _toast('Could not remove friend', error: true);
    } finally {
      if (mounted) setState(() => _unfriending = false);
    }
  }

  Future<void> _block() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(widget.friend.displayName),
        message: const Text('Block this person? They will be removed from your friends and won\'t be able to send you requests.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Block'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _blocking = true);
    try {
      await ref.read(socialControllerProvider).blockUser(userId: widget.friend.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _toast('Could not block user', error: true);
    } finally {
      if (mounted) setState(() => _blocking = false);
    }
  }

  Future<void> _report() async {
    HapticFeedback.lightImpact();
    String? selectedReason;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Report'),
        message: const Text('Why are you reporting this person?'),
        actions: [
          for (final reason in ['Spam', 'Harassment', 'Fake account', 'Inappropriate content', 'Other'])
            CupertinoActionSheetAction(
              onPressed: () {
                selectedReason = reason;
                Navigator.of(ctx).pop();
              },
              child: Text(reason),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selectedReason == null || !mounted) return;
    try {
      await ref.read(socialControllerProvider).reportUser(
            userId: widget.friend.userId,
            reason: selectedReason,
          );
      if (!mounted) return;
      _toast('Report submitted. Thank you.');
    } catch (_) {
      if (!mounted) return;
      _toast('Could not submit report', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.errorText : AppColors.accent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final sharedGroups = groups.where((g) => true).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 4),
              child: Row(
                children: [
                   IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.6,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      showCupertinoModalPopup<void>(
                        context: context,
                        builder: (ctx) => CupertinoActionSheet(
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => QrCodeScreen(userId: widget.friend.userId, name: widget.friend.displayName),
                                ));
                              },
                              child: const Text('Share profile'),
                            ),
                            CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () { Navigator.of(ctx).pop(); _report(); },
                              child: const Text('Report'),
                            ),
                            CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () { Navigator.of(ctx).pop(); _block(); },
                              child: const Text('Block'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(CupertinoIcons.ellipsis_circle, color: AppColors.accent, size: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          PersonAvatar(name: widget.friend.displayName, radius: 44),
                          const SizedBox(height: 14),
                          Text(
                            widget.friend.displayName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF000000),
                              letterSpacing: -0.5,
                              fontFamily: 'Manrope',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.friend.phoneNumber,
                            style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
                          ),
                          const SizedBox(height: 8),
                          if (widget.friend.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.circle_fill, size: 8, color: Color(0xFF34C759)),
                                  SizedBox(width: 5),
                                  Text('Open to plans',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF34C759),
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          _ActionRow(
                            onMessage: () {
                              HapticFeedback.lightImpact();
                              _toast('Messaging coming soon');
                            },
                            onQr: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => QrCodeScreen(userId: widget.friend.userId, name: widget.friend.displayName),
                            )),
                            onRemove: _unfriend,
                            unfriending: _unfriending,
                            blocking: _blocking,
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                  if (sharedGroups.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
                        child: Text(
                          'SHARED GROUPS',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8E8E93),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final g = sharedGroups[i];
                            final isFirst = i == 0;
                            final isLast = i == sharedGroups.length - 1;
                            return _GroupRow(group: g, isFirst: isFirst, isLast: isLast);
                          },
                          childCount: sharedGroups.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onMessage,
    required this.onQr,
    required this.onRemove,
    required this.unfriending,
    required this.blocking,
  });
  final VoidCallback onMessage;
  final VoidCallback onQr;
  final VoidCallback onRemove;
  final bool unfriending;
  final bool blocking;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleAction(
          icon: CupertinoIcons.chat_bubble_fill,
          label: 'Message',
          color: AppColors.accent,
          onTap: onMessage,
        ),
        const SizedBox(width: 20),
        _CircleAction(
          icon: CupertinoIcons.qrcode,
          label: 'Share',
          color: const Color(0xFF8E8E93),
          onTap: onQr,
        ),
        const SizedBox(width: 20),
        _CircleAction(
          icon: unfriending || blocking
              ? CupertinoIcons.hourglass
              : CupertinoIcons.person_badge_minus,
          label: 'Remove',
          color: const Color(0xFFFF3B30),
          onTap: onRemove,
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.isFirst, required this.isLast});
  final SparkGroup group;
  final bool isFirst;
  final bool isLast;

  BorderRadius get _radius {
    if (isFirst && isLast) return BorderRadius.circular(14);
    if (isFirst) return const BorderRadius.vertical(top: Radius.circular(14));
    if (isLast) return const BorderRadius.vertical(bottom: Radius.circular(14));
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 1),
      decoration: BoxDecoration(color: Colors.white, borderRadius: _radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.person_2_fill,
                  size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                          fontFamily: 'Manrope')),
                  Text('${group.memberCount} members',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
