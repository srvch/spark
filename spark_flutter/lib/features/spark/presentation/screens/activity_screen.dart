import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../../features/chat/presentation/screens/chat_screen.dart';
import '../controllers/spark_controller.dart';
import '../../domain/spark.dart';
import 'create_spark_screen.dart';
import 'spark_detail_screen.dart';

const _kNavy = AppColors.accent;
const _kNavyLight = AppColors.accentSurface;
const _kSurface = AppColors.surfaceSubtle;

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final joined = ref.watch(joinedSparksProvider);
    final created = ref.watch(myCreatedSparksProvider);
    final items = _tabIndex == 0 ? joined : created;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => backOrGoDiscover(context, ref),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'My Activity',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: -0.5,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.cardDivider),
            // ── Segmented tab row ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SegmentedTabs(
                labels: [
                  'Joined (${joined.length})',
                  'Created (${created.length})',
                ],
                selected: _tabIndex,
                onSelect: (i) => setState(() => _tabIndex = i),
              ),
            ),
            const SizedBox(height: 16),
            // ── Thick divider ──────────────────────────────────────
            Container(height: 4, color: AppColors.pillSurface),
            // ── List or empty ──────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(
                      tab: _tabIndex == 0 ? 'joined' : 'created',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final spark = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ActivityCard(
                            spark: spark,
                            createdMode: _tabIndex == 1,
                            onView: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SparkDetailScreen(spark: spark),
                              ),
                            ),
                            onChat: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(spark: spark),
                              ),
                            ),
                            onLeave: () async {
                              await ref
                                  .read(sparkDataControllerProvider)
                                  .leaveSpark(spark.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('You left this spark')),
                                );
                              }
                            },
                            onCancel: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Cancel Spark?'),
                                  content: Text(
                                    'This will remove "${spark.title}" for all participants.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                      ),
                                      child: const Text('Keep'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.errorText,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Cancel Spark'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && context.mounted) {
                                HapticFeedback.mediumImpact();
                                await ref
                                    .read(sparkDataControllerProvider)
                                    .cancelSpark(spark.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Spark cancelled')),
                                  );
                                }
                              }
                            },
                            onPostAgain: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CreateSparkScreen(prefill: spark),
                                ),
                              );
                            },
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

// ── Segmented tab control ─────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? _kNavy : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _kNavy.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Manrope',
                    color: isSelected ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});
  final String tab;

  @override
  Widget build(BuildContext context) {
    final isJoined = tab == 'joined';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kNavyLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isJoined
                  ? Icons.group_outlined
                  : Icons.add_circle_outline_rounded,
              size: 32,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isJoined ? 'No sparks joined yet' : 'No sparks created yet',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kNavy,
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isJoined
                ? 'Browse nearby sparks and jump in'
                : 'Tap + to create your first spark',
            style: const TextStyle(
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

// ── Activity card ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.spark,
    required this.createdMode,
    required this.onView,
    required this.onChat,
    required this.onLeave,
    required this.onCancel,
    required this.onPostAgain,
  });

  final Spark spark;
  final bool createdMode;
  final VoidCallback onView;
  final VoidCallback onChat;
  final VoidCallback onLeave;
  final VoidCallback onCancel;
  final VoidCallback onPostAgain;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 4, color: AppColors.accentSurface),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              spark.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
                                fontFamily: 'Manrope',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              spark.category.icon,
                              size: 15,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            spark.timeLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            spark.distanceLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(height: 1, color: AppColors.cardDivider),
                      // Action row
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            _ActionButton(
                              label: 'View',
                              color: _kNavy,
                              onTap: onView,
                            ),
                            if (!createdMode) ...[
                              _Divider(),
                              _ActionButton(
                                label: 'Chat',
                                color: _kNavy,
                                onTap: onChat,
                              ),
                              _Divider(),
                              _ActionButton(
                                label: 'Leave',
                                color: AppColors.errorText,
                                onTap: onLeave,
                              ),
                            ] else ...[
                              _Divider(),
                              _ActionButton(
                                label: 'Post again',
                                color: _kNavy,
                                onTap: onPostAgain,
                              ),
                              _Divider(),
                              _ActionButton(
                                label: 'Cancel',
                                color: AppColors.errorText,
                                onTap: onCancel,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                fontFamily: 'Manrope',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.cardDivider,
    );
  }
}
