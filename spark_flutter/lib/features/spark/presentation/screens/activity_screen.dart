import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/chat/presentation/screens/chat_screen.dart';
import '../controllers/spark_controller.dart';
import '../../domain/spark.dart';
import 'spark_detail_screen.dart';

final _kNavy = AppColors.accent;
const _kNavyLight = Color(0xFFEAF0FF);
const _kSurface = Color(0xFFF7F8FC);

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _kNavy),
        ),
        title: const Text(
          'My Activity',
          style: TextStyle(
            fontSize: 20,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Container(height: 4, color: const Color(0xFFF5F5F7)),
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
                            onLeave: () {
                              final next = {
                                ...ref.read(joinedSparkIdsProvider),
                              }..remove(spark.id);
                              ref
                                  .read(joinedSparkIdsProvider.notifier)
                                  .state = next;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('You left this spark')),
                              );
                            },
                            onDelete: () {
                              final next = [
                                ...ref.read(createdSparksProvider)
                              ]..removeWhere((s) => s.id == spark.id);
                              ref
                                  .read(createdSparksProvider.notifier)
                                  .state = next;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Spark deleted')),
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
                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
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
              color: Color(0xFF9CA3AF),
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
    required this.onDelete,
  });

  final Spark spark;
  final bool createdMode;
  final VoidCallback onView;
  final VoidCallback onChat;
  final VoidCallback onLeave;
  final VoidCallback onDelete;

  Color get _accentColor {
    switch (spark.category) {
      case SparkCategory.sports:
        return const Color(0xFF86EFAC);
      case SparkCategory.study:
        return const Color(0xFF93C5FD);
      case SparkCategory.ride:
        return const Color(0xFFC4B5FD);
      case SparkCategory.events:
        return const Color(0xFFFDBA74);
      case SparkCategory.hangout:
        return const Color(0xFFF9A8D4);
    }
  }

  Color get _darkColor {
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              Container(width: 5, color: _accentColor),
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
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              spark.category.icon,
                              size: 16,
                              color: _darkColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            spark.timeLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.location_on_outlined,
                              size: 13, color: Colors.black38),
                          const SizedBox(width: 3),
                          Text(
                            spark.distanceLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                          height: 1, color: const Color(0xFFF0F1F5)),
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
                                color: const Color(0xFFDC2626),
                                onTap: onLeave,
                              ),
                            ] else ...[
                              _Divider(),
                              _ActionButton(
                                label: 'Delete',
                                color: const Color(0xFFDC2626),
                                onTap: onDelete,
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
      color: const Color(0xFFF0F1F5),
    );
  }
}
