import 'package:flutter/cupertino.dart';
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
  ConsumerState<InviteToGroupSheet> createState() =>
      _InviteToGroupSheetState();
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

  List<FriendUser> _eligible(List<FriendUser> friends) {
    final q = _query.toLowerCase();
    return friends
        .where((f) => !widget.existingMemberIds.contains(f.userId))
        .where((f) => q.isEmpty
            ? true
            : f.displayName.toLowerCase().contains(q) ||
                f.phoneNumber.contains(q))
        .toList();
  }

  Future<void> _invite(FriendUser friend) async {
    if (_sending.contains(friend.userId)) return;
    setState(() => _sending.add(friend.userId));
    try {
      await ref.read(socialControllerProvider).inviteFriendToGroup(
            groupId: widget.groupId, userId: friend.userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${friend.displayName}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.accent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send invite. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending.remove(friend.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final eligible = _eligible(friends);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Invite to group',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF000000),
                        letterSpacing: -0.2,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E5EA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.xmark,
                          size: 13, color: Color(0xFF8E8E93)),
                    ),
                  ),
                ],
              ),
            ),

            if (friends.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: _EmptyNote(
                  icon: CupertinoIcons.person_2,
                  text: 'Add friends first to invite them to groups.',
                ),
              )
            else ...[
              // Search
              if (friends.length > 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF000000)),
                      decoration: const InputDecoration(
                        hintText: 'Search friends',
                        hintStyle: TextStyle(
                            color: Color(0xFF8E8E93), fontSize: 15),
                        prefixIcon: Icon(CupertinoIcons.search,
                            size: 16, color: Color(0xFF8E8E93)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 9),
                        filled: false,
                      ),
                    ),
                  ),
                ),

              if (eligible.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: _EmptyNote(
                    icon: CupertinoIcons.checkmark_circle,
                    text: _query.isNotEmpty
                        ? 'No friends match your search.'
                        : 'All your friends are already in this group.',
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin:
                          const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      color: Colors.white,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: eligible.length,
                        separatorBuilder: (_, i) => const Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 58,
                          color: Color(0xFFE5E5EA),
                        ),
                        itemBuilder: (_, i) {
                          final friend = eligible[i];
                          final isSending =
                              _sending.contains(friend.userId);
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                PersonAvatar(
                                    name: friend.displayName,
                                    radius: 19),
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
                                          fontSize: 12.5,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                isSending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CupertinoActivityIndicator(
                                            radius: 9),
                                      )
                                    : GestureDetector(
                                        onTap: () => _invite(friend),
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            'Invite',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.accent,
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8E8E93)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF8E8E93),
              height: 1.4,
            ),
          ),
        ),
      ],
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
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => InviteToGroupSheet(
      groupId: groupId,
      existingMemberIds: existingMemberIds,
    ),
  );
}
