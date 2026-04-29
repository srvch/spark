import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../domain/social.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import '../controllers/social_controller.dart';
import '../widgets/invite_to_group_sheet.dart';
import 'friend_profile_screen.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  late Future<GroupDetail> _detailFuture;
  late Future<List<OutgoingGroupInvite>> _pendingInvitesFuture;
  final _nudging = <String>{};
  final _removing = <String>{};
  bool _saving = false;
  bool _leavingOrArchiving = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = _load();
    _pendingInvitesFuture = _loadPendingInvites();
  }

  Future<GroupDetail> _load() =>
      ref.read(socialApiRepositoryProvider).fetchGroupDetail(widget.groupId);

  Future<List<OutgoingGroupInvite>> _loadPendingInvites() => ref
      .read(socialApiRepositoryProvider)
      .fetchPendingGroupInvites(widget.groupId);

  Future<void> _refresh() async {
    setState(() {
      _detailFuture = _load();
      _pendingInvitesFuture = _loadPendingInvites();
    });
    await _detailFuture;
  }

  Future<void> _nudge(GroupMember member) async {
    if (_nudging.contains(member.userId)) return;
    HapticFeedback.lightImpact();
    setState(() => _nudging.add(member.userId));
    try {
      await ref
          .read(socialControllerProvider)
          .nudgePendingMember(groupId: widget.groupId, userId: member.userId);
      if (!mounted) return;
      _toast('Nudge sent to ${member.displayName}');
    } catch (_) {
      if (!mounted) return;
      _toast('Could not nudge', error: true);
    } finally {
      if (mounted) setState(() => _nudging.remove(member.userId));
    }
  }

  Future<void> _removeMember(GroupDetail group, GroupMember member) async {
    HapticFeedback.mediumImpact();
    await showCupertinoModalPopup<void>(
      context: context,
      builder:
          (ctx) => CupertinoActionSheet(
            title: Text(member.displayName),
            message: const Text('Remove this person from the group?'),
            actions: [
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (_removing.contains(member.userId)) return;
                  setState(() => _removing.add(member.userId));
                  try {
                    await ref
                        .read(socialControllerProvider)
                        .removeMemberFromGroup(
                          groupId: widget.groupId,
                          userId: member.userId,
                        );
                    if (!mounted) return;
                    _toast('${member.displayName} removed');
                    await _refresh();
                  } catch (_) {
                    if (!mounted) return;
                    _toast('Could not remove', error: true);
                  } finally {
                    if (mounted)
                      setState(() => _removing.remove(member.userId));
                  }
                },
                child: const Text('Remove from group'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ),
    );
  }

  Future<void> _memberActions(GroupDetail group, GroupMember member) async {
    HapticFeedback.lightImpact();
    await showCupertinoModalPopup<void>(
      context: context,
      builder:
          (ctx) => CupertinoActionSheet(
            title: Text(member.displayName),
            actions: [
              if (group.isOwner && member.canBePromoted)
                CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ref
                          .read(socialControllerProvider)
                          .promoteToAdmin(
                            groupId: widget.groupId,
                            userId: member.userId,
                          );
                      _toast('${member.displayName} is now an admin');
                      HapticFeedback.mediumImpact();
                      await _refresh();
                    } catch (_) {
                      _toast('Could not promote', error: true);
                    }
                  },
                  child: const Text('Make admin'),
                ),
              if (group.isOwner && member.canBeDemoted)
                CupertinoActionSheetAction(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ref
                          .read(socialControllerProvider)
                          .demoteToMember(
                            groupId: widget.groupId,
                            userId: member.userId,
                          );
                      _toast('${member.displayName} is now a member');
                      await _refresh();
                    } catch (_) {
                      _toast('Could not demote', error: true);
                    }
                  },
                  child: const Text('Remove admin role'),
                ),
              if (group.canEdit && !member.isOwner)
                CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _removeMember(group, member);
                  },
                  child: const Text('Remove from group'),
                ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _reportMember(member);
                },
                child: const Text('Report'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ),
    );
  }

  Future<void> _reportMember(GroupMember member) async {
    try {
      await ref
          .read(socialControllerProvider)
          .reportUser(userId: member.userId);
      _toast('Report submitted');
    } catch (_) {
      _toast('Could not submit report', error: true);
    }
  }

  Future<void> _editGroup(GroupDetail group) async {
    HapticFeedback.lightImpact();
    final nameCtrl = TextEditingController(text: group.name);
    final descCtrl = TextEditingController(text: group.description);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setModal) => _EditGroupSheet(
                  nameController: nameCtrl,
                  descController: descCtrl,
                  saving: _saving,
                  onSave: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    setModal(() => _saving = true);
                    try {
                      await ref
                          .read(socialControllerProvider)
                          .updateGroup(
                            groupId: widget.groupId,
                            name: name,
                            description: descCtrl.text.trim(),
                          );
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      _toast('Group updated');
                      HapticFeedback.mediumImpact();
                      await _refresh();
                    } catch (_) {
                      if (!mounted) return;
                      _toast('Could not update group', error: true);
                    } finally {
                      if (mounted) setModal(() => _saving = false);
                    }
                  },
                  onCancel: () => Navigator.of(ctx).pop(),
                ),
          ),
    );
  }

  Future<void> _leaveGroup() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder:
          (ctx) => CupertinoActionSheet(
            title: const Text('Leave Group'),
            message: const Text(
              'You will no longer be a member of this group.',
            ),
            actions: [
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Leave group'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leavingOrArchiving = true);
    try {
      await ref
          .read(socialControllerProvider)
          .leaveGroup(groupId: widget.groupId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast('Could not leave group: $e', error: true);
    } finally {
      if (mounted) setState(() => _leavingOrArchiving = false);
    }
  }

  Future<void> _archiveGroup() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder:
          (ctx) => CupertinoActionSheet(
            title: const Text('Archive Group'),
            message: const Text(
              'The group will be hidden from your list. Members won\'t be notified.',
            ),
            actions: [
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Archive group'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leavingOrArchiving = true);
    try {
      await ref
          .read(socialControllerProvider)
          .archiveGroup(groupId: widget.groupId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast('Could not archive group', error: true);
    } finally {
      if (mounted) setState(() => _leavingOrArchiving = false);
    }
  }

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
    return FutureBuilder<GroupDetail>(
      future: _detailFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SkeletonDetail();
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, title: 'Group', group: null),
                  Expanded(child: Center(child: _ErrorView(onRetry: _refresh))),
                ],
              ),
            ),
          );
        }
        final group = snap.data!;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, title: group.name, group: group),
                Expanded(
                  child: RefreshIndicator.adaptive(
                    onRefresh: _refresh,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: _GroupHeaderCard(group: group),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _ActionRow(
                              group: group,
                              leavingOrArchiving: _leavingOrArchiving,
                              onCreateSpark: () {
                                HapticFeedback.lightImpact();
                                ref
                                    .read(sparkCreationContextProvider.notifier)
                                    .state = widget.groupId;
                                ref.read(bottomTabProvider.notifier).state = 1;
                                Navigator.of(context).pop();
                              },
                              onInvite:
                                  () => showInviteToGroupSheet(
                                    context,
                                    groupId: widget.groupId,
                                    existingMemberIds:
                                        group.members
                                            .map((m) => m.userId)
                                            .toList(),
                                  ).then((_) => _refresh()),
                              onLeave: group.isOwner ? null : _leaveGroup,
                              onArchive: group.isOwner ? _archiveGroup : null,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 16, 6),
                            child: Text(
                              'MEMBERS  ${group.members.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E8E93),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(group.members.length, (
                                  i,
                                ) {
                                  final m = group.members[i];
                                  return _MemberRow(
                                    member: m,
                                    isFirst: i == 0,
                                    isLast: i == group.members.length - 1,
                                    showSeparator: i < group.members.length - 1,
                                    canManage: group.canEdit && !m.isOwner,
                                    isNudging: _nudging.contains(m.userId),
                                    isRemoving: _removing.contains(m.userId),
                                    onNudge:
                                        group.canEdit && !m.isOwner
                                            ? () => _nudge(m)
                                            : null,
                                    onTap:
                                        () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => FriendProfileScreen(
                                                  friend: FriendUser(
                                                    userId: m.userId,
                                                    displayName: m.displayName,
                                                    phoneNumber: m.phoneNumber,
                                                  ),
                                                ),
                                          ),
                                        ),
                                    onManage:
                                        group.canEdit && !m.isOwner
                                            ? () => _memberActions(group, m)
                                            : null,
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                        _PendingInvitesSection(future: _pendingInvitesFuture),
                        const SliverToBoxAdapter(child: SizedBox(height: 48)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String title,
    GroupDetail? group,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.7,
                fontFamily: 'Manrope',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (group != null && group.canEdit)
            IconButton(
              onPressed: () => _editGroup(group),
              icon: const Icon(
                CupertinoIcons.pencil_circle,
                color: AppColors.accent,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Sliver Sections ─────────────────────────────────────────────────────────

class _PendingInvitesSection extends StatelessWidget {
  const _PendingInvitesSection({required this.future});
  final Future<List<OutgoingGroupInvite>> future;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<OutgoingGroupInvite>>(
        future: future,
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (items.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text(
                    'AWAITING RESPONSE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: List.generate(items.length, (i) {
                      final inv = items[i];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                PersonAvatar(name: inv.inviteeName, radius: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inv.inviteeName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                          fontFamily: 'Manrope',
                                        ),
                                      ),
                                      Text(
                                        inv.inviteePhone,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF9500,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'Pending',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFFFF9500),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i < items.length - 1)
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
            ),
          );
        },
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _SkeletonDetail extends StatefulWidget {
  const _SkeletonDetail();

  @override
  State<_SkeletonDetail> createState() => _SkeletonDetailState();
}

class _SkeletonDetailState extends State<_SkeletonDetail>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder:
          (context, _) => Opacity(
            opacity: _anim.value,
            child: Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (int i = 0; i < 3; i++) ...[
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5EA),
                          borderRadius:
                              i == 0
                                  ? const BorderRadius.vertical(
                                    top: Radius.circular(14),
                                  )
                                  : i == 2
                                  ? const BorderRadius.vertical(
                                    bottom: Radius.circular(14),
                                  )
                                  : BorderRadius.zero,
                        ),
                      ),
                      if (i < 2) const SizedBox(height: 1),
                    ],
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

// ─── Edit Group Sheet ─────────────────────────────────────────────────────────

class _EditGroupSheet extends StatelessWidget {
  const _EditGroupSheet({
    required this.nameController,
    required this.descController,
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });
  final TextEditingController nameController;
  final TextEditingController descController;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Edit Group',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      hintText: 'Group name',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Manrope',
                    ),
                    maxLength: 140,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 14,
                    color: Color(0xFFE5E5EA),
                  ),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      hintText: 'Description (optional)',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF3C3C43),
                    ),
                    maxLength: 280,
                    maxLines: 3,
                    minLines: 1,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: saving ? null : onSave,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child:
                      saving
                          ? const CupertinoActivityIndicator(
                            color: Colors.white,
                          )
                          : const Text(
                            'Save changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Manrope',
                            ),
                          ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Components ───────────────────────────────────────────────────────────────

class _GroupHeaderCard extends StatelessWidget {
  const _GroupHeaderCard({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PersonAvatar(name: group.name, radius: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'Manrope',
                  ),
                ),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    group.description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF8E8E93),
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Pill(
                      icon: CupertinoIcons.person_2_fill,
                      label: '${group.members.length}',
                    ),
                    const SizedBox(width: 6),
                    _Pill(
                      icon:
                          group.isOwner
                              ? CupertinoIcons.star_fill
                              : group.isAdmin
                              ? CupertinoIcons.shield_fill
                              : CupertinoIcons.person_fill,
                      label: group.myRole,
                      accent: group.isOwner || group.isAdmin,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.accent = false});
  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.action : const Color(0xFF8E8E93);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.group,
    required this.leavingOrArchiving,
    required this.onCreateSpark,
    required this.onInvite,
    this.onLeave,
    this.onArchive,
  });
  final GroupDetail group;
  final bool leavingOrArchiving;
  final VoidCallback onCreateSpark;
  final VoidCallback onInvite;
  final VoidCallback? onLeave;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: CupertinoIcons.bolt_fill,
                label: 'Create Spark',
                onTap: onCreateSpark,
                primary: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: CupertinoIcons.person_add,
                label: 'Add member',
                onTap: onInvite,
                primary: false,
              ),
            ),
          ],
        ),
        if (onLeave != null || onArchive != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (onLeave != null)
                Expanded(
                  child: _ActionButton(
                    icon: CupertinoIcons.square_arrow_left,
                    label: 'Leave',
                    onTap: leavingOrArchiving ? () {} : onLeave!,
                    primary: false,
                    destructive: true,
                  ),
                ),
              if (onLeave != null && onArchive != null)
                const SizedBox(width: 10),
              if (onArchive != null)
                Expanded(
                  child: _ActionButton(
                    icon: CupertinoIcons.archivebox,
                    label: 'Archive',
                    onTap: leavingOrArchiving ? () {} : onArchive!,
                    primary: false,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fgColor =
        primary
            ? Colors.white
            : destructive
            ? const Color(0xFFFF3B30)
            : const Color(0xFF000000);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: primary ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: fgColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fgColor,
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isFirst,
    required this.isLast,
    required this.showSeparator,
    required this.canManage,
    required this.isNudging,
    required this.isRemoving,
    this.onNudge,
    this.onTap,
    this.onManage,
  });

  final GroupMember member;
  final bool isFirst;
  final bool isLast;
  final bool showSeparator;
  final bool canManage;
  final bool isNudging;
  final bool isRemoving;
  final VoidCallback? onNudge;
  final VoidCallback? onTap;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onManage,
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  PersonAvatar(name: member.displayName, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontFamily: 'Manrope',
                          ),
                        ),
                        Text(
                          member.phoneNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (member.isOwner)
                    _Pill(
                      icon: CupertinoIcons.star_fill,
                      label: 'Owner',
                      accent: true,
                    )
                  else if (member.isAdmin)
                    _Pill(
                      icon: CupertinoIcons.shield_fill,
                      label: 'Admin',
                      accent: true,
                    )
                  else if (canManage) ...[
                    if (isNudging || isRemoving)
                      const CupertinoActivityIndicator(radius: 9)
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onNudge != null)
                            _IconAction(
                              icon: CupertinoIcons.bell,
                              color: AppColors.accent,
                              onTap: onNudge!,
                            ),
                          const SizedBox(width: 4),
                          const Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: Color(0xFFC7C7CC),
                          ),
                        ],
                      ),
                  ] else
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: Color(0xFFC7C7CC),
                    ),
                ],
              ),
            ),
            if (showSeparator)
              const Divider(
                height: 1,
                thickness: 0.5,
                indent: 58,
                endIndent: 0,
                color: Color(0xFFE5E5EA),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          CupertinoIcons.exclamationmark_circle,
          size: 36,
          color: Color(0xFF8E8E93),
        ),
        const SizedBox(height: 12),
        const Text(
          'Could not load group',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF000000),
          ),
        ),
        const SizedBox(height: 16),
        CupertinoButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
