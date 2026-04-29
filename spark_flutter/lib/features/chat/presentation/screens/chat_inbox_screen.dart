import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import 'chat_screen.dart';

const _kNavy      = Color(0xFF1E3A5F);
const _kNavyLight = Color(0xFFEAF2FF);
const _kScreenTitleSize = 24.0;

class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  bottom: BorderSide(
                      color: AppColors.cardDivider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => backOrGoDiscover(context, ref),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: _kNavy,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Expanded(
                    child: Text(
                      'Chats',
                      style: TextStyle(
                        fontSize: _kScreenTitleSize,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                        letterSpacing: -0.7,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: available.isEmpty
                  ? const _EmptyInbox()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: available.length,
                      separatorBuilder: (_, __) => Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 74),
                        color: AppColors.cardDivider,
                      ),
                      itemBuilder: (context, index) {
                        final spark = available[index];
                        final isJoined =
                            joinedIds.contains(spark.id);
                        final createdByMe =
                            created.any((s) => s.id == spark.id);
                        return _InboxRow(
                          spark: spark,
                          joined: isJoined,
                          created: createdByMe,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatScreen(spark: spark),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty inbox ───────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kNavyLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 38,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Keep in touch',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _kNavy,
              fontFamily: 'Manrope',
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your joined and created sparks will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inbox row ─────────────────────────────────────────────────────────────────

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

  static String _categoryEmoji(SparkCategory cat) => switch (cat) {
    SparkCategory.sports  => '⚽',
    SparkCategory.study   => '📚',
    SparkCategory.ride    => '🛵',
    SparkCategory.events  => '🎉',
    SparkCategory.hangout => '☕',
  };

  static Color _categoryBg(SparkCategory cat) => switch (cat) {
    SparkCategory.sports  => AppColors.catSports,
    SparkCategory.study   => AppColors.catStudy,
    SparkCategory.ride    => AppColors.catRide,
    SparkCategory.events  => AppColors.catEvents,
    SparkCategory.hangout => AppColors.catHangout,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Category emoji badge
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _categoryBg(spark.category),
                shape: BoxShape.circle,
              ),
              child: Text(
                _categoryEmoji(spark.category),
                style: const TextStyle(fontSize: 20),
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
                  const SizedBox(height: 2),
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
                        if (joined) _Badge(label: 'Joined'),
                        if (joined && created)
                          const SizedBox(width: 5),
                        if (created) _Badge(label: 'Host'),
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
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
