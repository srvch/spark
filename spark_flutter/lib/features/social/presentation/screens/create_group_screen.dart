import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../controllers/social_controller.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _selectedFriends = <String>{};
  final _phoneNumbers = <String>[];
  var _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _canCreate => _name.text.trim().isNotEmpty;

  Future<void> _create() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final group = await ref.read(socialControllerProvider).createGroup(
        name: _name.text.trim(),
        description: _description.text.trim(),
      );

      final friendIds = _selectedFriends.toList();
      final errors = <String>[];
      for (final friendId in friendIds) {
        try {
          await ref.read(socialControllerProvider).inviteFriendToGroup(
            groupId: group.groupId,
            userId: friendId,
          );
        } catch (_) {
          errors.add(friendId);
        }
      }

      for (final phone in _phoneNumbers) {
        try {
          await ref.read(socialControllerProvider).sendFriendRequest(phone);
        } catch (_) {}
      }

      if (!mounted) return;
      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedFriends.isEmpty && _phoneNumbers.isEmpty
                  ? '"${group.name}" created. Invite friends any time.'
                  : '"${group.name}" created. Invites sent!',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Group created. Some invites could not be sent.',
            ),
          ),
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create group. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addPhone() {
    final value = _phone.text.trim();
    if (value.isEmpty) return;
    final clean = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^[+]?[0-9]{8,15}$').hasMatch(clean)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }
    if (_phoneNumbers.contains(value)) return;
    setState(() {
      _phoneNumbers.add(value);
      _phone.clear();
    });
  }

  void _toggleFriend(String id) {
    setState(() {
      if (_selectedFriends.contains(id)) {
        _selectedFriends.remove(id);
      } else {
        _selectedFriends.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Create group',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Manrope',
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: (_canCreate && !_isSaving) ? _create : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _FieldLabel('Group name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'e.g. Cricket crew, Airport gang',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (v.trim().length < 2) return 'At least 2 characters';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _FieldLabel('Description (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What is this group for?',
                border: OutlineInputBorder(),
              ),
            ),

            if (friends.isNotEmpty) ...[
              const SizedBox(height: 24),
              _FieldLabel(
                'Invite friends  ${_selectedFriends.isNotEmpty ? "(${_selectedFriends.length} selected)" : ""}',
              ),
              const SizedBox(height: 6),
              const Text(
                'Select friends to invite right away — you can always add more later.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...friends.map((friend) {
                final selected = _selectedFriends.contains(friend.userId);
                return InkWell(
                  onTap: () => _toggleFriend(friend.userId),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accent.withValues(alpha: 0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.accent.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        PersonAvatar(name: friend.displayName, radius: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                friend.phoneNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accent : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),
            _FieldLabel('Invite by phone number'),
            const SizedBox(height: 6),
            const Text(
              "Add phone numbers for people who aren't on Spark yet.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+91 98XXXXXX10',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addPhone(),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: FilledButton(
                    onPressed: _addPhone,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      backgroundColor: AppColors.surfaceDim,
                      foregroundColor: AppColors.accent,
                    ),
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
            ),
            if (_phoneNumbers.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _phoneNumbers.map((phone) {
                  return Chip(
                    avatar: const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: AppColors.accent,
                    ),
                    label: Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14),
                    onDeleted: () => setState(() => _phoneNumbers.remove(phone)),
                    backgroundColor: AppColors.accentTint,
                    side: BorderSide(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 32),
            FilledButton(
              onPressed: (_canCreate && !_isSaving) ? _create : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.accent,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create group',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: 'Manrope',
      ),
    );
  }
}
