import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import 'chat_screen.dart';

const _kNavy = AppColors.accent;
const _kNavyLight = Color(0xFFEAF0FF);

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: Container(height: 1, color: const Color(0xFFF0F1F5)),
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
                  color: const Color(0xFFF0F1F5),
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
              color: Color(0xFF9CA3AF),
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

  Color get _accentBg {
    switch (spark.category) {
      case SparkCategory.sports:
        return const Color(0xFFDCFCE7);
      case SparkCategory.study:
        return const Color(0xFFDBEAFE);
      case SparkCategory.ride:
        return const Color(0xFFEDE9FE);
      case SparkCategory.events:
        return const Color(0xFFFEF3C7);
      case SparkCategory.hangout:
        return const Color(0xFFFCE7F3);
    }
  }

  Color get _accentIcon {
    switch (spark.category) {
      case SparkCategory.sports:
        return const Color(0xFF15803D);
      case SparkCategory.study:
        return const Color(0xFF1D4ED8);
      case SparkCategory.ride:
        return const Color(0xFF6D28D9);
      case SparkCategory.events:
        return const Color(0xFFC2410C);
      case SparkCategory.hangout:
        return const Color(0xFFBE185D);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _accentBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(spark.category.icon, color: _accentIcon, size: 22),
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
                      color: Color(0xFF9CA3AF),
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
              color: Color(0xFFD1D5DB),
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
