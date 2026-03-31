import 'package:flutter/material.dart';

import '../../features/spark/domain/spark.dart';

class ActivityMap extends StatefulWidget {
  const ActivityMap({
    super.key,
    required this.sparks,
    this.onTap,
    this.height = 112,
    this.embedded = false,
  });

  final List<Spark> sparks;
  final VoidCallback? onTap;
  final double height;
  final bool embedded;

  @override
  State<ActivityMap> createState() => _ActivityMapState();
}

class _ActivityMapState extends State<ActivityMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapBody = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ActivityMapPainter(
          sparks: widget.sparks,
          pulseValue: _controller,
        ),
      ),
    );

    if (widget.embedded) {
      return RepaintBoundary(child: mapBody);
    }

    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        elevation: 0.8,
        shadowColor: const Color(0x140F172A),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: widget.onTap, child: mapBody),
      ),
    );
  }
}

class _ActivityMapPainter extends CustomPainter {
  _ActivityMapPainter({required this.sparks, required this.pulseValue})
    : super(repaint: pulseValue);

  final List<Spark> sparks;
  final Animation<double> pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    _drawBaseMapTexture(canvas, size);
    _drawSparkDots(canvas, size, pulseValue.value);
  }

  void _drawBaseMapTexture(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0x140F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path1 = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.08,
        size.width,
        size.height * 0.28,
      );
    final path2 = Path()
      ..moveTo(0, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.56,
        size.width,
        size.height * 0.78,
      );
    final path3 = Path()
      ..moveTo(size.width * 0.12, 0)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.4,
        size.width * 0.2,
        size.height,
      );
    final path4 = Path()
      ..moveTo(size.width * 0.78, 0)
      ..quadraticBezierTo(
        size.width * 0.67,
        size.height * 0.34,
        size.width * 0.86,
        size.height,
      );

    canvas.drawPath(path1, linePaint);
    canvas.drawPath(path2, linePaint);
    canvas.drawPath(path3, linePaint);
    canvas.drawPath(path4, linePaint);
  }

  void _drawSparkDots(Canvas canvas, Size size, double t) {
    for (final spark in sparks) {
      final color = _colorForCategory(spark.category);
      final clusterCount = 1 + (spark.id.hashCode.abs() % 2);

      for (var cluster = 0; cluster < clusterCount; cluster++) {
        final clusterCenter = _clusterCenter(spark, size, cluster);
        final dotCount = (2 + (spark.joinedCount ~/ 2) + cluster).clamp(3, 6);

        for (var i = 0; i < dotCount; i++) {
          final point = _clusteredPoint(
            spark: spark,
            size: size,
            index: i,
            cluster: cluster,
            center: clusterCenter,
          );
          final baseRadius = 3 + ((spark.id.hashCode + i + cluster).abs() % 3);
          final phase = ((t + (i * 0.13) + (cluster * 0.2)) % 1);
          final opacity = 0.55 + (((spark.id.hashCode + i * 19) % 40) / 100);

          canvas.drawCircle(
            point,
            baseRadius + 1.5 + (5.5 * phase),
            Paint()..color = color.withValues(alpha: 0.1 * (1 - phase)),
          );
          canvas.drawCircle(
            point,
            baseRadius.toDouble(),
            Paint()..color = color.withValues(alpha: opacity),
          );
        }
      }
    }
  }

  Offset _clusterCenter(Spark spark, Size size, int cluster) {
    final seedA = (spark.id.hashCode + (cluster + 1) * 83).abs();
    final seedB = (spark.id.hashCode + (cluster + 1) * 149).abs();
    final xSeed = (seedA % 1000) / 1000;
    final ySeed = (seedB % 1000) / 1000;

    return Offset(
      size.width * (0.1 + xSeed * 0.8),
      size.height * (0.2 + ySeed * 0.6),
    );
  }

  Offset _clusteredPoint({
    required Spark spark,
    required Size size,
    required int index,
    required int cluster,
    required Offset center,
  }) {
    final seedA = (spark.id.hashCode + (index + 1) * 57 + cluster * 11).abs();
    final seedB = (spark.id.hashCode + (index + 1) * 131 + cluster * 17).abs();
    final xSeed = (seedA % 1000) / 1000;
    final ySeed = (seedB % 1000) / 1000;
    final dx = (xSeed - 0.5) * 34;
    final dy = (ySeed - 0.5) * 26;
    return Offset(
      (center.dx + dx).clamp(8, size.width - 8),
      (center.dy + dy).clamp(8, size.height - 8),
    );
  }

  Color _colorForCategory(SparkCategory category) {
    switch (category) {
      case SparkCategory.sports:
        return const Color(0xFF22C55E);
      case SparkCategory.study:
        return const Color(0xFF8B5CF6);
      case SparkCategory.ride:
        return const Color(0xFF2563EB);
      case SparkCategory.events:
        return const Color(0xFFF59E0B);
      case SparkCategory.hangout:
        return const Color(0xFF0EA5E9);
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityMapPainter oldDelegate) {
    return oldDelegate.sparks != sparks;
  }
}
