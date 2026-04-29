import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../controllers/auth_controller.dart';

class MandatoryProfileScreen extends ConsumerStatefulWidget {
  const MandatoryProfileScreen({super.key});

  @override
  ConsumerState<MandatoryProfileScreen> createState() =>
      _MandatoryProfileScreenState();
}

class _MandatoryProfileScreenState extends ConsumerState<MandatoryProfileScreen> {
  static const List<String> _ageBands = ['18-24', '25-34', '35-44', '45+'];
  static const List<String> _genders = ['MALE', 'FEMALE', 'OTHER'];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();
  String? _ageBand;
  String? _gender;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final handle = _normalizeHandle(_handleController.text);
    if (name.length < 2 ||
        !RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(handle) ||
        _ageBand == null ||
        _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .completeMandatoryProfile(
          displayName: name,
          handle: handle,
          ageBand: _ageBand!,
          gender: _gender!,
        );
  }

  String _normalizeHandle(String raw) {
    var value = raw.trim().toLowerCase();
    if (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Complete your profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Name, handle, age band, and gender are required to continue.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Full name *'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _handleController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Handle *',
                  hintText: 'e.g. @saurav',
                  helperText: '3-32 chars: a-z, 0-9, underscore',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _ageBand,
                items:
                    _ageBands
                        .map(
                          (band) =>
                              DropdownMenuItem(value: band, child: Text(band)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _ageBand = value),
                decoration: const InputDecoration(labelText: 'Age band *'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _gender,
                items:
                    _genders
                        .map(
                          (gender) => DropdownMenuItem(
                            value: gender,
                            child: Text(
                              gender[0] + gender.substring(1).toLowerCase(),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _gender = value),
                decoration: const InputDecoration(labelText: 'Gender *'),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dangerText,
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(auth.loading ? 'Saving...' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
