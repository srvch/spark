import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/chat/presentation/screens/chat_screen.dart';
import '../controllers/spark_controller.dart';
import '../../domain/spark.dart';
import 'spark_detail_screen.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String tab = 'joined';

  @override
  Widget build(BuildContext context) {
    final joined = ref.watch(joinedSparksProvider);
    final created = ref.watch(myCreatedSparksProvider);
    final items = tab == 'joined' ? joined : created;

    return Scaffold(
      appBar: AppBar(title: const Text('My Activity')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  _TabChip(
                    label: 'Joined (${joined.length})',
                    selected: tab == 'joined',
                    onTap: () => setState(() => tab = 'joined'),
                  ),
                  const SizedBox(width: 8),
                  _TabChip(
                    label: 'Created (${created.length})',
                    selected: tab == 'created',
                    onTap: () => setState(() => tab = 'created'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: items.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          tab == 'joined'
                              ? 'No joined sparks yet.'
                              : 'No created sparks yet.',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final spark = items[index];
                          return _ActivityItemCard(
                            spark: spark,
                            createdMode: tab == 'created',
                            onView: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SparkDetailScreen(spark: spark),
                                ),
                              );
                            },
                            onChat: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(spark: spark),
                                ),
                              );
                            },
                            onLeave: () {
                              final next = {
                                ...ref.read(joinedSparkIdsProvider),
                              }..remove(spark.id);
                              ref.read(joinedSparkIdsProvider.notifier).state = next;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('You left this spark')),
                              );
                            },
                            onDelete: () {
                              final next = [...ref.read(createdSparksProvider)]
                                ..removeWhere((s) => s.id == spark.id);
                              ref.read(createdSparksProvider.notifier).state = next;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Spark deleted')),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F426F) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ActivityItemCard extends StatelessWidget {
  const _ActivityItemCard({
    required this.spark,
    required this.createdMode,
    required this.onView,
    required this.onChat,
    required this.onLeave,
    required this.onDelete,
  });

  final Spark spark;
  final bool createdMode;
  final VoidCallback onView;
  final VoidCallback onChat;
  final VoidCallback onLeave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spark.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${spark.timeLabel} · ${spark.distanceLabel}',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              TextButton(onPressed: onView, child: const Text('View')),
              if (createdMode)
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                )
              else ...[
                TextButton(onPressed: onChat, child: const Text('Chat')),
                TextButton(
                  onPressed: onLeave,
                  child: const Text(
                    'Leave',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
