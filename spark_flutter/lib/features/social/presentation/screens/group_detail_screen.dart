import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../domain/social.dart';
import '../controllers/social_controller.dart';
import '../widgets/invite_to_group_sheet.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  late Future<GroupDetail> _detailFuture;
  final _nudging = <String>{};
  final _removing = <String>{};

  @override
  void initState() {
    super.initState();
    _detailFuture = _load();
  }

  Future<GroupDetail> _load() {
    return ref
        .read(socialApiRepositoryProvider)
        .fetchGroupDetail(widget.groupId);
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _detailFuture = fresh);
    await fresh;
  }

  Future<void> _nudge(GroupMember member) async {
    if (_nudging.contains(member.userId)) return;
    setState(() => _nudging.add(member.userId));
    try {
      await ref.read(socialControllerProvider).nudgePendingMember(
        groupId: widget.groupId,
        userId: member.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nudge sent to ${member.displayName}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not nudge. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _nudging.remove(member.userId));
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          'Remove ${member.displayName} from this group? They can be re-invited later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorText),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_removing.contains(member.userId)) return;
    setState(() => _removing.add(member.userId));
    try {
      await ref.read(socialControllerProvider).removeMemberFromGroup(
        groupId: widget.groupId,
        userId: member.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.displayName} removed from group')),
      );
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove member. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _removing.remove(member.userId));
    }
  }

  void _goCreateSpark() {
    ref.read(bottomTabProvider.notifier).state = 1;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<GroupDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: _backButton(context),
                title: const Text('Group'),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 40,
                        color: AppColors.errorText,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load group details.',
                        style: TextStyle(
                          color: AppColors.errorText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final group = snapshot.data!;
          return _GroupDetailBody(
            group: group,
            onRefresh: _refresh,
            onCreateSpark: _goCreateSpark,
            onInvite: () => showInviteToGroupSheet(
              context,
              groupId: widget.groupId,
              existingMemberIds: group.members.map((m) => m.userId).toList(),
            ).then((_) => _refresh()),
            onRemoveMember: group.isOwner ? _removeMember : null,
            onNudge: group.isOwner ? _nudge : null,
            nudging: _nudging,
            removing: _removing,
            onBack: () => Navigator.of(context).pop(),
          );
        },
      ),
    );
  }

  Widget _backButton(BuildContext ctx) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
      onPressed: () => Navigator.of(ctx).pop(),
    );
  }
}

class _GroupDetailBody extends StatelessWidget {
  const _GroupDetailBody({
    required this.group,
    required this.onRefresh,
    required this.onCreateSpark,
    required this.onInvite,
    required this.onBack,
    required this.nudging,
    required this.removing,
    this.onRemoveMember,
    this.onNudge,
  });

  final GroupDetail group;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreateSpark;
  final VoidCallback onInvite;
  final VoidCallback onBack;
  final void Function(GroupMember)? onRemoveMember;
  final void Function(GroupMember)? onNudge;
  final Set<String> nudging;
  final Set<String> removing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: onBack,
        ),
        title: Text(
          group.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _GroupHeader(group: group),
            const SizedBox(height: 16),
            _ActionRow(
              onCreateSpark: onCreateSpark,
              onInvite: onInvite,
            ),
            const SizedBox(height: 24),
            _MemberList(
              group: group,
              onRemoveMember: onRemoveMember,
              onNudge: onNudge,
              nudging: nudging,
              removing: removing,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontFamily: 'Manrope',
                  ),
                ),
                if (group.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    group.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Pill(
                      label: '${group.members.length} members',
                      icon: Icons.people_outline_rounded,
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      label: group.myRole,
                      icon: group.isOwner
                          ? Icons.star_rounded
                          : Icons.person_outline_rounded,
                      color: group.isOwner
                          ? AppColors.action
                          : AppColors.accent,
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
  const _Pill({required this.label, required this.icon, this.color});
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onCreateSpark, required this.onInvite});
  final VoidCallback onCreateSpark;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onCreateSpark,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.accent,
            ),
            icon: const Icon(Icons.flash_on_rounded, size: 16),
            label: const Text('Create Spark'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onInvite,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: AppColors.border),
            ),
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              size: 16,
              color: AppColors.textPrimary,
            ),
            label: const Text(
              'Add member',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.group,
    required this.nudging,
    required this.removing,
    this.onRemoveMember,
    this.onNudge,
  });

  final GroupDetail group;
  final void Function(GroupMember)? onRemoveMember;
  final void Function(GroupMember)? onNudge;
  final Set<String> nudging;
  final Set<String> removing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Members',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'Manrope',
          ),
        ),
        const SizedBox(height: 10),
        ...group.members.map(
          (member) => _MemberTile(
            member: member,
            isCurrentOwner: group.isOwner,
            isNudging: nudging.contains(member.userId),
            isRemoving: removing.contains(member.userId),
            onRemove:
                onRemoveMember != null && !member.isOwner
                    ? () => onRemoveMember!(member)
                    : null,
            onNudge:
                onNudge != null && !member.isOwner
                    ? () => onNudge!(member)
                    : null,
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCurrentOwner,
    required this.isNudging,
    required this.isRemoving,
    this.onRemove,
    this.onNudge,
  });

  final GroupMember member;
  final bool isCurrentOwner;
  final bool isNudging;
  final bool isRemoving;
  final VoidCallback? onRemove;
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          PersonAvatar(name: member.displayName, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  member.phoneNumber,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (member.isOwner)
            _Pill(
              label: 'Owner',
              icon: Icons.star_rounded,
              color: AppColors.action,
            )
          else if (isCurrentOwner) ...[
            if (onNudge != null)
              isNudging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: onNudge,
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 18,
                      ),
                      color: AppColors.accent,
                      tooltip: 'Nudge',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
            if (onRemove != null)
              isRemoving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: onRemove,
                      icon: const Icon(
                        Icons.person_remove_alt_1_rounded,
                        size: 18,
                      ),
                      color: AppColors.errorText,
                      tooltip: 'Remove',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                    ),
          ] else
            Text(
              member.role,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}
