import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import 'chat_screen.dart';

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
      appBar: AppBar(title: const Text('Chat')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: available.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'No chats yet. Join or create a spark to start chatting.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: available.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final spark = available[index];
                    final joined = joinedIds.contains(spark.id);
                    final createdByMe = created.any((s) => s.id == spark.id);
                    return _InboxRow(
                      spark: spark,
                      joined: joined,
                      created: createdByMe,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(spark: spark),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (joined) 'Joined',
      if (created) 'Created',
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE4EBFA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                spark.category.icon,
                color: const Color(0xFF2F426F),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${spark.timeLabel} · ${spark.distanceLabel}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      tags.join(' • '),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2F426F),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
