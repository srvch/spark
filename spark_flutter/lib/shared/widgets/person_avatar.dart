import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.fontSize,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String name;
  final double radius;
  final double? fontSize;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final colors = _colorsForName(name);
    final bg = backgroundColor ?? colors.$1;
    final fg = foregroundColor ?? colors.$2;
    final fs = fontSize ?? (radius * 0.7).clamp(10.0, 24.0);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initials,
        style: TextStyle(
          color: fg,
          fontSize: fs,
          fontWeight: FontWeight.w700,
          fontFamily: 'Manrope',
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  static String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // Apple-style: (pastel bg, deeper fg) pairs
  static const _palette = [
    (Color(0xFFFFE5E5), Color(0xFFBF2E2E)), // red
    (Color(0xFFFFEDD5), Color(0xFFB84D00)), // orange
    (Color(0xFFFFF9C2), Color(0xFF8A6900)), // yellow
    (Color(0xFFD9F5E5), Color(0xFF1A7A45)), // green
    (Color(0xFFD1F0FA), Color(0xFF0A6A9B)), // teal
    (Color(0xFFDCEEFF), Color(0xFF1249A0)), // blue
    (Color(0xFFEAE0FF), Color(0xFF5B28C4)), // purple
    (Color(0xFFFFE0F3), Color(0xFFAA1C72)), // pink
    (Color(0xFFE0F7EE), Color(0xFF18735A)), // mint
    (Color(0xFFF0E8FF), Color(0xFF6B3FA0)), // lavender
  ];

  static (Color, Color) _colorsForName(String name) {
    if (name.isEmpty) return (AppColors.accentSurface, AppColors.accent);
    final index = name.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    return _palette[index];
  }
}
