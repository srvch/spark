import 'package:flutter/material.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.backgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final Color? backgroundColor;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.98 : 1,
        child: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(widget.compact ? 46 : 50),
            backgroundColor: widget.backgroundColor,
          ),
          onPressed: widget.onPressed,
          child: Text(widget.label),
        ),
      ),
    );
  }
}
