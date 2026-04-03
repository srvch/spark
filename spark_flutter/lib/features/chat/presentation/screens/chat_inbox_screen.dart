import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/domain/spark_invite.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import 'chat_screen.dart';

const _kNavy = AppColors.accent;
const _kNavyLight = AppColors.accentSurface;
final chatInboxTabProvider = StateProvider<int>((ref) => 0);

class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(sparkDataControllerProvider).refreshInvites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final joinedIds = ref.watch(joinedSparkIdsProvider);
    final all = ref.watch(allSparksProvider);
    final created = ref.watch(myCreatedSparksProvider);
    final joined = all.where((s) => joinedIds.contains(s.id)).toList();
    final byId = <String, Spark>{};
    for (final spark in [...joined, ...created]) {
      byId[spark.id] = spark;
    }
    final available = byId.values.toList();
    final invites = ref.watch(sparkInvitesProvider);
    final invitesLoading = ref.watch(sparkInvitesLoadingProvider);
    final invitesError = ref.watch(sparkInvitesErrorProvider);
    final tab = ref.watch(chatInboxTabProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _kNavy,
          ),
          onPressed: () => backOrGoDiscover(context, ref),
        ),
        title: const Text(
          'Chats',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _kNavy,
            fontFamily: 'Manrope',
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Column(
            children: [
              Container(height: 1, color: AppColors.cardDivider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _SegmentButton(
                        label: 'Chats',
                        selected: tab == 0,
                        onTap: () => ref.read(chatInboxTabProvider.notifier).state = 0,
                      ),
                      _SegmentButton(
                        label: 'Invites',
                        selected: tab == 1,
                        badge: invites.where((i) => i.status == SparkInviteStatus.pending).length,
                        onTap: () => ref.read(chatInboxTabProvider.notifier).state = 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: tab == 0
            ? (available.isEmpty
                ? _EmptyInbox()
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: available.length,
                    separatorBuilder: (_, _) => Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 72),
                      color: AppColors.cardDivider,
                    ),
                    itemBuilder: (context, index) {
                      final spark = available[index];
                      final isJoined = joinedIds.contains(spark.id);
                      final createdByMe = created.any((s) => s.id == spark.id);
                      return _InboxRow(
                        spark: spark,
                        joined: isJoined,
                        created: createdByMe,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(spark: spark),
                          ),
                        ),
                      );
                    },
                  ))
            : _InvitesTab(
                invites: invites,
                loading: invitesLoading,
                error: invitesError,
                onRetry: () => ref.read(sparkDataControllerProvider).refreshInvites(),
                onRespond: (invite, status) async {
                  try {
                    await ref.read(sparkDataControllerProvider).respondToInvite(
                          invite: invite,
                          status: status,
                        );
                    if (!context.mounted) return;
                    final text = switch (status) {
                      SparkInviteStatus.inStatus => 'Joined "${invite.title}"',
                      SparkInviteStatus.maybe => 'Marked Maybe for "${invite.title}"',
                      SparkInviteStatus.declined => 'Declined "${invite.title}"',
                      SparkInviteStatus.pending => 'Updated invite',
                    };
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(text)),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not update invite: $e')),
                    );
                  }
                },
              ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected ? Border.all(color: AppColors.border) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitesTab extends StatelessWidget {
  const _InvitesTab({
    required this.invites,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onRespond,
  });

  final List<SparkInvite> invites;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Future<void> Function(SparkInvite invite, SparkInviteStatus status) onRespond;

  @override
  Widget build(BuildContext context) {
    if (loading && invites.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && invites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load invites',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (invites.isEmpty) {
      return const Center(
        child: Text(
          'No invites yet',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: invites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final invite = invites[index];
        final subtitleTime = invite.startsAt == null
            ? ''
            : ' · ${_timeDelta(invite.startsAt!)}';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(invite.category.icon, size: 15, color: AppColors.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      invite.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'From ${invite.fromUserId} · ${invite.locationName}$subtitleTime',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InviteActionChip(
                    label: 'Join',
                    selected: invite.status == SparkInviteStatus.inStatus,
                    onTap: () => onRespond(invite, SparkInviteStatus.inStatus),
                  ),
                  _InviteActionChip(
                    label: 'Maybe',
                    selected: invite.status == SparkInviteStatus.maybe,
                    onTap: () => onRespond(invite, SparkInviteStatus.maybe),
                  ),
                  _InviteActionChip(
                    label: 'Decline',
                    selected: invite.status == SparkInviteStatus.declined,
                    onTap: () => onRespond(invite, SparkInviteStatus.declined),
                    danger: true,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  static String _timeDelta(DateTime startsAt) {
    final diff = startsAt.difference(DateTime.now());
    if (diff.inMinutes <= 0) return 'Starting now';
    if (diff.inMinutes < 60) return 'Starts in ${diff.inMinutes} min';
    return 'Starts in ${diff.inHours} hr';
  }
}

class _InviteActionChip extends StatelessWidget {
  const _InviteActionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final selectedColor = danger ? AppColors.errorText : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selectedColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? selectedColor : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? selectedColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _kNavyLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 32,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kNavy,
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Join or create a spark to start chatting',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.spark,
    required this.joined,
    required this.created,
    required this.onTap,
  });

  final Spark spark;
  final bool joined;
  final bool created;
  final VoidCallback onTap;

  static IconData _categoryIcon(SparkCategory cat) => switch (cat) {
        SparkCategory.sports => Icons.directions_run_rounded,
        SparkCategory.study => Icons.auto_stories_rounded,
        SparkCategory.ride => Icons.drive_eta_rounded,
        SparkCategory.events => Icons.confirmation_number_outlined,
        SparkCategory.hangout => Icons.coffee_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _categoryIcon(spark.category),
                color: AppColors.accent,
                size: 19,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spark.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kNavy,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${spark.timeLabel} · ${spark.distanceLabel}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (joined || created) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (joined)
                          _Badge(label: 'Joined'),
                        if (joined && created) const SizedBox(width: 5),
                        if (created)
                          _Badge(label: 'Host'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.onSurfaceFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _kNavyLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _kNavy,
          fontFamily: 'Manrope',
        ),
      ),
    );
  }
}
