import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../domain/social.dart';
import '../controllers/social_controller.dart';

Future<void> showInviteToGroupSheet(
  BuildContext context, {
  required String groupId,
  List<String> existingMemberIds = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => InviteToGroupSheet(
      groupId: groupId,
      existingMemberIds: existingMemberIds,
    ),
  );
}

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

  final _phoneCtrl = TextEditingController();
  bool _lookingUp = false;
  MatchedContact? _phoneResult;
  bool _phoneResultChecked = false;
  bool _sendingRequest = false;
  bool _requestSent = false;

  @override
  void dispose() {
    _search.dispose();
    _phoneCtrl.dispose();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _inviteByUserId(String userId, String displayName) async {
    setState(() => _sending.add(userId));
    try {
      await ref.read(socialControllerProvider).inviteFriendToGroup(
            groupId: widget.groupId, userId: userId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to $displayName'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add this person as a friend first to invite them.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending.remove(userId));
    }
  }

  Future<void> _lookupPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _lookingUp = true;
      _phoneResult = null;
      _phoneResultChecked = false;
      _requestSent = false;
    });
    try {
      final results = await ref
          .read(socialApiRepositoryProvider)
          .matchContacts([phone]);
      setState(() {
        _phoneResult = results.isNotEmpty ? results.first : null;
        _phoneResultChecked = true;
        _lookingUp = false;
      });
    } catch (_) {
      setState(() {
        _lookingUp = false;
        _phoneResultChecked = true;
      });
    }
  }

  Future<void> _sendFriendRequest(String phone) async {
    setState(() => _sendingRequest = true);
    try {
      await ref.read(socialControllerProvider).sendFriendRequest(phone);
      HapticFeedback.lightImpact();
      setState(() {
        _requestSent = true;
        _sendingRequest = false;
      });
    } catch (_) {
      setState(() => _sendingRequest = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send request. Try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final friendIds = friends.map((f) => f.userId).toSet();
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

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
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

            // ── Phone lookup (always shown at top) ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Search by phone number',
                          hintStyle: TextStyle(
                              color: Color(0xFFC7C7CC), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          prefixIcon: Icon(CupertinoIcons.phone,
                              size: 16, color: Color(0xFF8E8E93)),
                        ),
                        onSubmitted: (_) => _lookupPhone(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _lookingUp ? null : _lookupPhone,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _lookingUp
                            ? const CupertinoActivityIndicator(
                                color: Colors.white)
                            : const Text(
                                'Find',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  fontFamily: 'Manrope',
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Phone lookup result
            if (_phoneResultChecked) ...[
              const SizedBox(height: 12),
              if (_phoneResult == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: _EmptyNote(
                    icon: CupertinoIcons.person_badge_minus,
                    text: 'This number isn\'t on Spark yet.',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        PersonAvatar(name: _phoneResult!.displayName, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _phoneResult!.displayName,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Manrope',
                                ),
                              ),
                              Text(
                                _phoneResult!.phoneNumber,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF8E8E93)),
                              ),
                            ],
                          ),
                        ),
                        if (widget.existingMemberIds
                            .contains(_phoneResult!.userId))
                          const Text('In group',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF8E8E93),
                                  fontWeight: FontWeight.w500))
                        else if (friendIds.contains(_phoneResult!.userId))
                          GestureDetector(
                            onTap: _sending.contains(_phoneResult!.userId)
                                ? null
                                : () => _inviteByUserId(
                                    _phoneResult!.userId,
                                    _phoneResult!.displayName),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: _sending.contains(_phoneResult!.userId)
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CupertinoActivityIndicator(
                                          radius: 7))
                                  : Text(
                                      'Invite',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                            ),
                          )
                        else if (_requestSent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text('Request sent',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF8E8E93),
                                    fontWeight: FontWeight.w600)),
                          )
                        else
                          GestureDetector(
                            onTap: _sendingRequest
                                ? null
                                : () => _sendFriendRequest(
                                    _phoneResult!.phoneNumber),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: _sendingRequest
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CupertinoActivityIndicator(
                                          color: Colors.white, radius: 7))
                                  : const Text(
                                      'Add friend',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],

            // ── Friends ────────────────────────────────────────────────────
            if (eligible.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'FRIENDS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E8E93),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
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
                        hintStyle:
                            TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                        prefixIcon: Icon(CupertinoIcons.search,
                            size: 16, color: Color(0xFF8E8E93)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 9),
                        filled: false,
                      ),
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.38,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                        final isSending = _sending.contains(friend.userId);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              PersonAvatar(
                                  name: friend.displayName, radius: 19),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          radius: 9))
                                  : GestureDetector(
                                      onTap: () => _invite(friend),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 6),
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
            ] else if (friends.isEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: _EmptyNote(
                  icon: CupertinoIcons.person_2,
                  text: 'Add friends first to invite them to groups.',
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: _EmptyNote(
                  icon: CupertinoIcons.checkmark_circle,
                  text: _query.isNotEmpty
                      ? 'No friends match your search.'
                      : 'All your friends are already in this group.',
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
              fontSize: 13.5,
              color: Color(0xFF8E8E93),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
