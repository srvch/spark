import 'package:flutter/cupertino.dart';
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

  Future<GroupDetail> _load() =>
      ref.read(socialApiRepositoryProvider).fetchGroupDetail(widget.groupId);

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _detailFuture = f);
    await f;
  }

  Future<void> _nudge(GroupMember member) async {
    if (_nudging.contains(member.userId)) return;
    setState(() => _nudging.add(member.userId));
    try {
      await ref.read(socialControllerProvider).nudgePendingMember(
            groupId: widget.groupId, userId: member.userId);
      if (!mounted) return;
      _toast('Nudge sent to ${member.displayName}');
    } catch (_) {
      if (!mounted) return;
      _toast('Could not nudge', error: true);
    } finally {
      if (mounted) setState(() => _nudging.remove(member.userId));
    }
  }

  Future<void> _removeMember(GroupMember member) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(member.displayName),
        message:
            const Text('Remove this person from the group?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (_removing.contains(member.userId)) return;
              setState(() => _removing.add(member.userId));
              try {
                await ref.read(socialControllerProvider).removeMemberFromGroup(
                      groupId: widget.groupId, userId: member.userId);
                if (!mounted) return;
                _toast('${member.displayName} removed');
                await _refresh();
              } catch (_) {
                if (!mounted) return;
                _toast('Could not remove', error: true);
              } finally {
                if (mounted) setState(() => _removing.remove(member.userId));
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: FutureBuilder<GroupDetail>(
        future: _detailFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF2F2F7),
              body: Center(
                child: CupertinoActivityIndicator(radius: 12),
              ),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return Scaffold(
              backgroundColor: const Color(0xFFF2F2F7),
              appBar: _buildAppBar(context, title: 'Group'),
              body: Center(
                child: _ErrorView(onRetry: _refresh),
              ),
            );
          }
          final group = snap.data!;
          return Scaffold(
            backgroundColor: const Color(0xFFF2F2F7),
            appBar: _buildAppBar(context, title: group.name),
            body: RefreshIndicator.adaptive(
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
                        onCreateSpark: () {
                          ref.read(bottomTabProvider.notifier).state = 1;
                          Navigator.of(context).pop();
                        },
                        onInvite: () => showInviteToGroupSheet(
                          context,
                          groupId: widget.groupId,
                          existingMemberIds: group.members
                              .map((m) => m.userId)
                              .toList(),
                        ).then((_) => _refresh()),
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
                          children: List.generate(group.members.length, (i) {
                            final m = group.members[i];
                            return _MemberRow(
                              member: m,
                              isFirst: i == 0,
                              isLast: i == group.members.length - 1,
                              showSeparator: i < group.members.length - 1,
                              isOwnerView: group.isOwner && !m.isOwner,
                              isNudging: _nudging.contains(m.userId),
                              isRemoving: _removing.contains(m.userId),
                              onNudge: group.isOwner && !m.isOwner
                                  ? () => _nudge(m)
                                  : null,
                              onRemove: group.isOwner && !m.isOwner
                                  ? () => _removeMember(m)
                                  : null,
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext ctx, {required String title}) {
    return AppBar(
      backgroundColor: const Color(0xFFF2F2F7),
      scrolledUnderElevation: 0,
      elevation: 0,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(ctx).pop(),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_left,
                color: AppColors.accent, size: 20),
          ],
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF000000),
          fontFamily: 'Manrope',
        ),
        overflow: TextOverflow.ellipsis,
      ),
      centerTitle: true,
    );
  }
}

class _GroupHeaderCard extends StatelessWidget {
  const _GroupHeaderCard({required this.group});
  final GroupDetail group;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    color: Color(0xFF000000),
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
                      icon: group.isOwner
                          ? CupertinoIcons.star_fill
                          : CupertinoIcons.person_fill,
                      label: group.myRole,
                      accent: group.isOwner,
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
  const _ActionRow({required this.onCreateSpark, required this.onInvite});
  final VoidCallback onCreateSpark;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
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
            Icon(icon,
                size: 15,
                color: primary ? Colors.white : const Color(0xFF000000)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primary ? Colors.white : const Color(0xFF000000),
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
    required this.isOwnerView,
    required this.isNudging,
    required this.isRemoving,
    this.onNudge,
    this.onRemove,
  });

  final GroupMember member;
  final bool isFirst;
  final bool isLast;
  final bool showSeparator;
  final bool isOwnerView;
  final bool isNudging;
  final bool isRemoving;
  final VoidCallback? onNudge;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                          color: Color(0xFF000000),
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
                else if (isOwnerView) ...[
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
                            tooltip: 'Nudge',
                          ),
                        if (onRemove != null) ...[
                          const SizedBox(width: 4),
                          _IconAction(
                            icon: CupertinoIcons.person_badge_minus,
                            color: const Color(0xFFFF3B30),
                            onTap: onRemove!,
                            tooltip: 'Remove',
                          ),
                        ],
                      ],
                    ),
                ] else
                  Text(
                    member.role,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                    ),
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
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

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
        const Icon(CupertinoIcons.exclamationmark_circle,
            size: 36, color: Color(0xFF8E8E93)),
        const SizedBox(height: 12),
        const Text(
          'Could not load group',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF000000)),
        ),
        const SizedBox(height: 16),
        CupertinoButton(
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    );
  }
}
