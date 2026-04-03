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
    final bg = backgroundColor ?? _colorForName(name);
    final fg = foregroundColor ?? Colors.white;
    final fs = fontSize ?? (radius * 0.7).clamp(10.0, 24.0);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initials,
        style: TextStyle(
          color: fg,
          fontSize: fs,
          fontWeight: FontWeight.w800,
          fontFamily: 'Manrope',
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

  static Color _colorForName(String name) {
    const palette = [
      Color(0xFF1E3A5F),
      Color(0xFF2F426F),
      Color(0xFF0F766E),
      Color(0xFF6D28D9),
      Color(0xFFB45309),
      Color(0xFFBE185D),
      Color(0xFF15803D),
      Color(0xFF1D4ED8),
    ];
    if (name.isEmpty) return AppColors.accent;
    final index = name.codeUnits.fold(0, (a, b) => a + b) % palette.length;
    return palette[index];
  }
}
