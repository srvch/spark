import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import 'chat_screen.dart';

const _kNavy = AppColors.accent;
const _kNavyLight = AppColors.accentSurface;

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
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.cardDivider),
        ),
      ),
      body: SafeArea(
        child: available.isEmpty
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
