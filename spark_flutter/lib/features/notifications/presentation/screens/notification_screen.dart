import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import '../../../spark/presentation/screens/spark_detail_screen.dart';
import '../controllers/notification_controller.dart';
import '../../data/notification_api_repository.dart';

const _kScreenTitleSize = 24.0;

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationControllerProvider);

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
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: _kScreenTitleSize,
                        fontWeight: FontWeight.w800,
                        color: context.palette.textPrimary,
                        letterSpacing: -0.7,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        () =>
                            ref
                                .read(notificationControllerProvider.notifier)
                                .refresh(),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notificationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final n = list[index];
                      return _NotificationCard(notification: n);
                    },
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

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});
  final SparkNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification.readAt != null;

    return InkWell(
      onTap: () async {
        if (!isRead) {
          await ref
              .read(notificationControllerProvider.notifier)
              .markRead(notification.id);
        }
        final sparkId = notification.sparkId;
        if (sparkId == null || sparkId.isEmpty) return;
        await ref.read(sparkDataControllerProvider).fetchSparkDetail(sparkId);
        final spark =
            ref
                .read(allSparksProvider)
                .where((s) => s.id == sparkId)
                .firstOrNull;
        if (spark == null || !context.mounted) return;
        final type = notification.type.toUpperCase();
        final openChat =
            type.contains('JOIN') ||
            type.contains('LEAVE') ||
            type.contains('START') ||
            type.contains('FILLING') ||
            type.contains('CHAT');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) =>
                    openChat
                        ? ChatScreen(spark: spark)
                        : SparkDetailScreen(spark: spark),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isRead
                  ? context.palette.surface
                  : AppColors.accentSurface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isRead
                    ? AppColors.border
                    : AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(notification.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
