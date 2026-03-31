import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../controllers/auth_controller.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              const Text(
                'Welcome to Spark',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Login with your mobile number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: 'e.g. +919999999999',
                ),
              ),
              const SizedBox(height: 10),
              if (auth.otpRequested) ...[
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'OTP',
                    hintText: 'Enter 6-digit OTP',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (auth.debugOtp != null && auth.debugOtp!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB6CCFF)),
                  ),
                  child: Text(
                    'Dev OTP: ${auth.debugOtp}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2F426F),
                    ),
                  ),
                ),
              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Spacer(),
              if (!auth.otpRequested)
                PrimaryButton(
                  label: auth.loading ? 'SENDING OTP...' : 'SEND OTP',
                  backgroundColor: const Color(0xFF2F426F),
                  onPressed: auth.loading
                      ? null
                      : () => ref
                            .read(authControllerProvider.notifier)
                            .requestOtp(phoneController.text.trim()),
                )
              else
                PrimaryButton(
                  label: auth.loading ? 'VERIFYING...' : 'VERIFY & CONTINUE',
                  backgroundColor: const Color(0xFF2F426F),
                  onPressed: auth.loading
                      ? null
                      : () => ref.read(authControllerProvider.notifier).verifyOtp(
                            phone: phoneController.text.trim(),
                            otp: otpController.text.trim(),
                          ),
                ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: auth.loading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).loginAsGuest(),
                child: const Text(
                  'LOGIN AS GUEST (DEV)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
