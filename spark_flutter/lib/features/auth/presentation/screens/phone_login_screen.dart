import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  late final AnimationController _orbCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  Animation<double> _fadeSlide(double from, double to) =>
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Interval(from, to, curve: Curves.easeOut),
      );

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    _entryCtrl.dispose();
    _orbCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _Background(orbCtrl: _orbCtrl),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 56),

                  // Logo + wordmark
                  FadeTransition(
                    opacity: _fadeSlide(0.0, 0.45),
                    child: _SlideIn(
                      animation: _fadeSlide(0.0, 0.45),
                      child: _LogoSection(pulseCtrl: _pulseCtrl),
                    ),
                  ),

                  const SizedBox(height: 52),

                  // Phone label + field
                  FadeTransition(
                    opacity: _fadeSlide(0.2, 0.6),
                    child: _SlideIn(
                      animation: _fadeSlide(0.2, 0.6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Mobile number'),
                          const SizedBox(height: 8),
                          _GlassField(
                            controller: _phoneController,
                            focusNode: _phoneFocus,
                            keyboardType: TextInputType.phone,
                            hintText: '+91 98765 43210',
                            icon: Icons.phone_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // OTP field — animated in when requested
                  AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                    child: auth.otpRequested
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _FieldLabel('Verification code'),
                                const SizedBox(height: 8),
                                _GlassField(
                                  controller: _otpController,
                                  focusNode: _otpFocus,
                                  keyboardType: TextInputType.number,
                                  hintText: '· · · · · ·',
                                  icon: Icons.lock_rounded,
                                  centerText: true,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Dev OTP hint
                  if (auth.debugOtp != null && auth.debugOtp!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.key_rounded,
                              size: 14,
                              color: Colors.white38,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Dev OTP: ${auth.debugOtp}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Error
                  if (auth.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        auth.error!,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Primary CTA
                  FadeTransition(
                    opacity: _fadeSlide(0.45, 0.85),
                    child: _SlideIn(
                      animation: _fadeSlide(0.45, 0.85),
                      child: _PrimaryButton(
                        label: auth.loading
                            ? (auth.otpRequested ? 'Verifying...' : 'Sending...')
                            : (auth.otpRequested ? 'Verify & Continue' : 'Send OTP'),
                        loading: auth.loading,
                        onTap: auth.loading
                            ? null
                            : () {
                                if (auth.otpRequested) {
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .verifyOtp(
                                        phone: _phoneController.text.trim(),
                                        otp: _otpController.text.trim(),
                                      );
                                } else {
                                  ref
                                      .read(authControllerProvider.notifier)
                                      .requestOtp(_phoneController.text.trim());
                                }
                              },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Guest link
                  FadeTransition(
                    opacity: _fadeSlide(0.6, 1.0),
                    child: TextButton(
                      onPressed: auth.loading
                          ? null
                          : () => ref
                              .read(authControllerProvider.notifier)
                              .loginAsGuest(),
                      child: const Text(
                        'Continue as guest',
                        style: TextStyle(
                          color: Colors.white30,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Background ──────────────────────────────────────────────────────────────

class _Background extends StatelessWidget {
  const _Background({required this.orbCtrl});
  final AnimationController orbCtrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0C1829),
                Color(0xFF182847),
                Color(0xFF0C1829),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: orbCtrl,
          builder: (_, __) {
            final t = orbCtrl.value;
            return Stack(
              children: [
                _Orb(
                  x: 0.08 + 0.06 * math.sin(t * math.pi),
                  y: 0.18 + 0.05 * math.cos(t * math.pi),
                  size: 220,
                  color: const Color(0xFF86EFAC).withValues(alpha: 0.09),
                ),
                _Orb(
                  x: 0.78 + 0.05 * math.cos(t * math.pi * 1.2),
                  y: 0.12 + 0.06 * math.sin(t * math.pi * 1.2),
                  size: 260,
                  color: const Color(0xFFC4B5FD).withValues(alpha: 0.08),
                ),
                _Orb(
                  x: 0.55 + 0.07 * math.sin(t * math.pi * 0.6),
                  y: 0.72 + 0.04 * math.cos(t * math.pi * 0.6),
                  size: 310,
                  color: const Color(0xFF93C5FD).withValues(alpha: 0.07),
                ),
                _Orb(
                  x: 0.2 + 0.04 * math.cos(t * math.pi * 1.5),
                  y: 0.85 + 0.03 * math.sin(t * math.pi * 1.5),
                  size: 180,
                  color: const Color(0xFFFDBA74).withValues(alpha: 0.06),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
  });
  final double x, y, size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (_, constraints) => Stack(
          children: [
            Positioned(
              left: x * constraints.maxWidth - size / 2,
              top: y * constraints.maxHeight - size / 2,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logo section ─────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection({required this.pulseCtrl});
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) {
            final glow = pulseCtrl.value;
            return Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3A55A4), Color(0xFF2F426F)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF86EFAC).withValues(alpha: 0.25 + 0.2 * glow),
                    blurRadius: 24 + 16 * glow,
                    spreadRadius: 2 + 4 * glow,
                  ),
                  BoxShadow(
                    color: const Color(0xFF93C5FD).withValues(alpha: 0.15 + 0.1 * glow),
                    blurRadius: 40 + 20 * glow,
                    spreadRadius: 4 + 6 * glow,
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 38,
                color: Colors.white,
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        const Text(
          'SPARK',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 10,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tiny plans. Real moments.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Colors.white38,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// ─── Slide-in wrapper ─────────────────────────────────────────────────────────

class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, 24 * (1 - animation.value)),
        child: child,
      ),
    );
  }
}

// ─── Field label ──────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white38,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Glass field ──────────────────────────────────────────────────────────────

class _GlassField extends StatefulWidget {
  const _GlassField({
    required this.controller,
    required this.focusNode,
    required this.keyboardType,
    required this.hintText,
    required this.icon,
    this.centerText = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType keyboardType;
  final String hintText;
  final IconData icon;
  final bool centerText;

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(
      () => setState(() => _focused = widget.focusNode.hasFocus),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: _focused
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused
              ? const Color(0xFF86EFAC).withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.10),
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: const Color(0xFF86EFAC).withValues(alpha: 0.10),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: widget.keyboardType,
        textAlign: widget.centerText ? TextAlign.center : TextAlign.start,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.22),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(widget.icon, size: 18, color: Colors.white30),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

// ─── Primary button ───────────────────────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    lowerBound: 0.0,
    upperBound: 0.03,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(
          scale: 1.0 - _press.value,
          child: child,
        ),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A55A4), Color(0xFF2F426F)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F426F).withValues(alpha: 0.6),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white60,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.white60,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
