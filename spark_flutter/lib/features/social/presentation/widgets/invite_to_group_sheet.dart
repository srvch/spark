import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../domain/social.dart';
import '../controllers/social_controller.dart';

class InviteToGroupSheet extends ConsumerStatefulWidget {
  const InviteToGroupSheet({
    super.key,
    required this.groupId,
    this.existingMemberIds = const [],
  });

  final String groupId;
  final List<String> existingMemberIds;

  @override
  ConsumerState<InviteToGroupSheet> createState() => _InviteToGroupSheetState();
}

class _InviteToGroupSheetState extends ConsumerState<InviteToGroupSheet> {
  String _query = '';
  final _search = TextEditingController();
  final _sending = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FriendUser> _filtered(List<FriendUser> friends) {
    final q = _query.toLowerCase();
    final eligible = friends
        .where((f) => !widget.existingMemberIds.contains(f.userId))
        .toList();
    if (q.isEmpty) return eligible;
    return eligible
        .where(
          (f) =>
              f.displayName.toLowerCase().contains(q) ||
              f.phoneNumber.contains(q),
        )
        .toList();
  }

  Future<void> _invite(FriendUser friend) async {
    if (_sending.contains(friend.userId)) return;
    setState(() => _sending.add(friend.userId));
    try {
      await ref.read(socialControllerProvider).inviteFriendToGroup(
        groupId: widget.groupId,
        userId: friend.userId,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to ${friend.displayName}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send invite. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _sending.remove(friend.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final filtered = _filtered(friends);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Invite to group',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                'Add friends first to invite them.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search friends',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: AppColors.surfaceDim,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Text(
                  'No friends match your search.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final friend = filtered[i];
                    final isSending = _sending.contains(friend.userId);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: PersonAvatar(name: friend.displayName, radius: 18),
                      title: Text(
                        friend.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        friend.phoneNumber,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: () => _invite(friend),
                              child: const Text(
                                'Invite',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Future<void> showInviteToGroupSheet(
  BuildContext context, {
  required String groupId,
  List<String> existingMemberIds = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (_) => InviteToGroupSheet(
      groupId: groupId,
      existingMemberIds: existingMemberIds,
    ),
  );
}
