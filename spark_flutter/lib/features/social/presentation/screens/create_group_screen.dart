import 'package:flutter/cupertino.dart';
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

  bool get _canCreate => _name.text.trim().length >= 2;

  Future<void> _create() async {
    if (!_canCreate || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final group = await ref.read(socialControllerProvider).createGroup(
        name: _name.text.trim(),
        description: _description.text.trim(),
      );

      for (final friendId in _selectedFriends) {
        try {
          await ref.read(socialControllerProvider).inviteFriendToGroup(
            groupId: group.groupId,
            userId: friendId,
          );
        } catch (_) {}
      }
      for (final phone in _phoneNumbers) {
        try {
          await ref.read(socialControllerProvider).sendFriendRequest(phone);
        } catch (_) {}
      }

      if (!mounted) return;
      _toast('"${group.name}" created!');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _toast('Could not create group. Try again.', error: true);
      setState(() => _isSaving = false);
    }
  }

  void _addPhone() {
    final raw = _phone.text.trim();
    if (raw.isEmpty) return;
    final clean = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^[+]?[0-9]{8,15}$').hasMatch(clean)) {
      _toast('Enter a valid phone number', error: true);
      return;
    }
    if (!_phoneNumbers.contains(raw)) {
      setState(() {
        _phoneNumbers.add(raw);
        _phone.clear();
      });
    }
  }

  void _toggleFriend(String id) => setState(() {
        _selectedFriends.contains(id)
            ? _selectedFriends.remove(id)
            : _selectedFriends.add(id);
      });

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.errorText : AppColors.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_left,
                  color: AppColors.accent, size: 20),
            ],
          ),
        ),
        title: const Text(
          'New group',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF000000),
            fontFamily: 'Manrope',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: (_canCreate && !_isSaving) ? _create : null,
              child: _isSaving
                  ? const CupertinoActivityIndicator(radius: 10)
                  : Text(
                      'Create',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _canCreate
                            ? AppColors.accent
                            : const Color(0xFFC7C7CC),
                        fontFamily: 'Manrope',
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Group identity ──────────────────────────────────────
          _SectionHeader('GROUP DETAILS'),
          _WhiteCard(
            child: Column(
              children: [
                _InsetField(
                  controller: _name,
                  hint: 'Group name',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),
                const _Separator(),
                _InsetField(
                  controller: _description,
                  hint: 'Description (optional)',
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),

          // ── Invite friends ──────────────────────────────────────
          if (friends.isNotEmpty) ...[
            _SectionHeader(
              'INVITE FRIENDS',
              trailing: _selectedFriends.isNotEmpty
                  ? '${_selectedFriends.length} selected'
                  : null,
            ),
            _WhiteCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(friends.length, (i) {
                  final friend = friends[i];
                  final selected = _selectedFriends.contains(friend.userId);
                  final isLast = i == friends.length - 1;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _toggleFriend(friend.userId),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                PersonAvatar(
                                    name: friend.displayName, radius: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend.displayName,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF000000),
                                          fontFamily: 'Manrope',
                                        ),
                                      ),
                                      Text(
                                        friend.phoneNumber,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.accent
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.accent
                                          : const Color(0xFFC7C7CC),
                                      width: 2,
                                    ),
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 14)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 58,
                          color: Color(0xFFE5E5EA),
                        ),
                    ],
                  );
                }),
              ),
            ),
          ],

          // ── Invite by phone ─────────────────────────────────────
          _SectionHeader('INVITE BY PHONE',
              trailing: 'People not on Spark yet'),
          _WhiteCard(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                              fontSize: 15, color: Color(0xFF000000)),
                          decoration: const InputDecoration(
                            hintText: '+91 98765 43210',
                            hintStyle: TextStyle(
                                color: Color(0xFF8E8E93), fontSize: 15),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                            filled: false,
                          ),
                          onSubmitted: (_) => _addPhone(),
                        ),
                      ),
                      GestureDetector(
                        onTap: _addPhone,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.add,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_phoneNumbers.isNotEmpty) ...[
                  const Divider(
                      height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _phoneNumbers
                          .map((phone) => _PhoneChip(
                                label: phone,
                                onRemove: () => setState(
                                    () => _phoneNumbers.remove(phone)),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Create button ───────────────────────────────────────
          GestureDetector(
            onTap: (_canCreate && !_isSaving) ? _create : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                color: _canCreate ? AppColors.accent : const Color(0xFFC7C7CC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: _isSaving
                    ? const CupertinoActivityIndicator(
                        color: Colors.white, radius: 10)
                    : const Text(
                        'Create group',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFamily: 'Manrope',
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-components
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.3,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8E8E93),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: Colors.white,
        child: child,
      ),
    );
  }
}

class _InsetField extends StatelessWidget {
  const _InsetField({
    required this.controller,
    required this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        minLines: 1,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF000000),
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: false,
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 14,
      color: Color(0xFFE5E5EA),
    );
  }
}

class _PhoneChip extends StatelessWidget {
  const _PhoneChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF000000),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 16,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }
}
