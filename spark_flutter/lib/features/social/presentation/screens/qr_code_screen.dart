import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';

class QrCodeScreen extends StatelessWidget {
  const QrCodeScreen({super.key, required this.userId, required this.name});
  final String userId;
  final String name;

  String get _deepLink => 'https://spark.app/add/$userId';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
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
                  const Expanded(
                    child: Text(
                      'Invite',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF000000),
                              letterSpacing: -0.3,
                              fontFamily: 'Manrope',
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Scan to add as a friend on Spark',
                            style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                          ),
                          const SizedBox(height: 28),
                          _QrPlaceholder(link: _deepLink),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SelectableText(
                              _deepLink,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8E8E93),
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: CupertinoIcons.square_on_square,
                            label: 'Copy link',
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(ClipboardData(text: _deepLink));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Link copied!'),
                                  backgroundColor: AppColors.accent,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: CupertinoIcons.share,
                            label: 'Share',
                            primary: true,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Share.share(
                                'Add me on Spark! $_deepLink',
                                subject: 'Join me on Spark',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({required this.link});
  final String link;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(painter: _QrPainter(data: link)),
    );
  }
}

class _QrPainter extends CustomPainter {
  const _QrPainter({required this.data});
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;
    final bg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      bg,
    );
    const cellCount = 21;
    final cellSize = size.width / cellCount;
    final hash = data.hashCode.abs();
    final finderPatterns = <Rect>[
      Rect.fromLTWH(0, 0, cellSize * 7, cellSize * 7),
      Rect.fromLTWH(size.width - cellSize * 7, 0, cellSize * 7, cellSize * 7),
      Rect.fromLTWH(0, size.height - cellSize * 7, cellSize * 7, cellSize * 7),
    ];
    for (final r in finderPatterns) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), paint);
      final inner = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(r.deflate(cellSize), inner);
      canvas.drawRect(r.deflate(cellSize * 2), paint);
    }
    final rng = hash;
    for (int row = 0; row < cellCount; row++) {
      for (int col = 0; col < cellCount; col++) {
        if (_inFinderZone(row, col, cellCount)) continue;
        final bit = ((rng ^ (row * 31 + col * 17)) & 1) == 1;
        if (bit) {
          canvas.drawRect(
            Rect.fromLTWH(col * cellSize + 1, row * cellSize + 1,
                cellSize - 2, cellSize - 2),
            paint,
          );
        }
      }
    }
  }

  bool _inFinderZone(int row, int col, int n) {
    if (row < 8 && col < 8) return true;
    if (row < 8 && col >= n - 8) return true;
    if (row >= n - 8 && col < 8) return true;
    return false;
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.data != data;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: primary ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: primary ? Colors.white : const Color(0xFF000000)),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.white : const Color(0xFF000000),
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
