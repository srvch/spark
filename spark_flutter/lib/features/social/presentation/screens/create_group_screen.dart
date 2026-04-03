import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
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

  bool get _canCreate {
    return _name.text.trim().isNotEmpty &&
        (_selectedFriends.isNotEmpty || _phoneNumbers.isNotEmpty);
  }

  Future<void> _create() async {
    if (!_canCreate || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final group = await ref
          .read(socialControllerProvider)
          .createGroup(
            name: _name.text.trim(),
            description: _description.text.trim(),
          );
      final friendIds = _selectedFriends.toList();
      for (final friendId in friendIds) {
        await ref
            .read(socialControllerProvider)
            .inviteFriendToGroup(groupId: group.groupId, userId: friendId);
      }
      for (final phoneNumber in _phoneNumbers) {
        await ref
            .read(socialControllerProvider)
            .sendFriendRequest(phoneNumber: phoneNumber);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created. Invites are in flight.')),
      );
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
    if (value.isEmpty || _phoneNumbers.contains(value)) return;
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
    final canCreate = _canCreate && !_isSaving;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create group'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ListView(
            children: [
              const Text('Name'),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  hintText: 'Group name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Description'),
              const SizedBox(height: 6),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Optional description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add friends'),
              const SizedBox(height: 6),
              if (friends.isEmpty)
                const Text(
                  'No friends yet. Add some to invite them right away.',
                )
              else
                ...friends.map((friend) {
                  return CheckboxListTile(
                    value: _selectedFriends.contains(friend.userId),
                    onChanged: (_) => _toggleFriend(friend.userId),
                    title: Text(friend.displayName),
                    subtitle: Text(friend.phoneNumber),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              const SizedBox(height: 16),
              const Text('Invite by phone'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '+91 98XXXXXX10',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _addPhone, child: const Text('Add')),
                ],
              ),
              if (_phoneNumbers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _phoneNumbers.map((phone) {
                    return Chip(
                      label: Text(phone),
                      onDeleted: () {
                        setState(() {
                          _phoneNumbers.remove(phone);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: canCreate ? _create : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create group'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
