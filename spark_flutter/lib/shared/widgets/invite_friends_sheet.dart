import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../features/spark/domain/spark.dart';

Future<void> showInviteFriendsBottomSheet({
  required BuildContext context,
  required Spark spark,
  required String source,
  VoidCallback? onViewSpark,
}) async {
  final link = 'https://spark.app/sparks/${spark.id}';
  final message = 'Join my Spark on Spark app\n'
      '${spark.title}\n'
      '${spark.timeLabel} · ${spark.location}\n'
      '$link';

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invite friends',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Fill spots faster by sharing this spark now.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  spark.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF2F426F),
                ),
                onPressed: () async {
                  final box = sheetContext.findRenderObject() as RenderBox?;
                  final shareOrigin = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : const Rect.fromLTWH(1, 1, 1, 1);
                  await Share.share(
                    message,
                    subject: 'Join my spark',
                    sharePositionOrigin: shareOrigin,
                  );
                },
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('SHARE INVITE'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!sheetContext.mounted) return;
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(content: Text('Invite link copied')),
                  );
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('COPY LINK'),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (onViewSpark != null)
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        onViewSpark();
                      },
                      child: const Text(
                        'VIEW SPARK',
                        style: TextStyle(
                          color: Color(0xFF2F426F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(
                      source == 'post_join' ? 'SKIP' : 'DONE',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
