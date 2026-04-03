import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../domain/social.dart';
import '../controllers/social_controller.dart';
import 'create_group_screen.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(socialControllerProvider).refreshAll());
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(socialLoadingProvider);
    final error = ref.watch(socialErrorProvider);
    final friends = ref.watch(friendsProvider);
    final friendRequests = ref.watch(incomingFriendRequestsProvider);
    final groups = ref.watch(groupsProvider);
    final groupInvites = ref.watch(incomingGroupInvitesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'People',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    icon: const Icon(Icons.person_outline_rounded),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.read(socialControllerProvider).refreshAll(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _tabChip('Friends', 0),
                  const SizedBox(width: 8),
                  _tabChip('Groups', 1),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _friendlyError(error),
                  style: const TextStyle(
                    color: AppColors.errorText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(socialControllerProvider).refreshAll(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    if (_tab == 0) ...[
                      if (friendRequests.isNotEmpty) ...[
                        _sectionTitle('Incoming requests'),
                        ...friendRequests.map(
                          (request) => _FriendRequestTile(
                            request: request,
                            onAccept: () => ref
                                .read(socialControllerProvider)
                                .respondFriendRequest(
                                  requestId: request.requestId,
                                  decision: FriendRequestDecision.accepted,
                                ),
                            onDecline: () => ref
                                .read(socialControllerProvider)
                                .respondFriendRequest(
                                  requestId: request.requestId,
                                  decision: FriendRequestDecision.declined,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _sectionHeaderWithAction(
                        title: 'Your friends',
                        actionLabel: '+ Add by phone',
                        onTap: _openAddFriendDialog,
                      ),
                      if (friends.isEmpty)
                        const _EmptyCard(text: 'No friends yet'),
                      ...friends.map(
                        (friend) => _SimpleRowTile(
                          title: friend.displayName,
                          subtitle: friend.phoneNumber,
                          trailingText: 'Friend',
                        ),
                      ),
                    ] else ...[
                      if (groupInvites.isNotEmpty) ...[
                        _sectionTitle('Incoming group invites'),
                        ...groupInvites.map(
                          (invite) => _GroupInviteTile(
                            invite: invite,
                            onAccept: () => ref
                                .read(socialControllerProvider)
                                .respondGroupInvite(
                                  groupId: invite.groupId,
                                  inviteId: invite.inviteId,
                                  decision: FriendRequestDecision.accepted,
                                ),
                            onDecline: () => ref
                                .read(socialControllerProvider)
                                .respondGroupInvite(
                                  groupId: invite.groupId,
                                  inviteId: invite.inviteId,
                                  decision: FriendRequestDecision.declined,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _sectionHeaderWithAction(
                        title: 'Your groups',
                        actionLabel: '+ Create group',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateGroupScreen(),
                          ),
                        ),
                      ),
                      if (groups.isEmpty)
                        const _EmptyCard(text: 'No groups yet'),
                      ...groups.map(
                        (group) => _SimpleRowTile(
                          title: group.name,
                          subtitle:
                              '${group.memberCount} members · ${group.myRole}',
                          trailingText: 'Invite',
                          onTap: () => _openGroupDetail(group.groupId),
                          onTrailingTap: () =>
                              _openInviteFriendSheet(group.groupId),
                        ),
                      ),
                    ],
                    if (loading) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(String label, int index) {
    final selected = _tab == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _tab = index),
      selectedColor: AppColors.accent.withValues(alpha: 0.12),
      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelStyle: TextStyle(
        color: selected ? AppColors.accent : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _sectionHeaderWithAction({
    required String title,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String error) {
    if (error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('socket') ||
        error.toLowerCase().contains('connection')) {
      return 'Could not connect. Please check backend/server and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _openAddFriendDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add friend by phone'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '+91 98XXXXXX10'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    if (!mounted || result == null || result.isEmpty) return;
    try {
      await ref.read(socialControllerProvider).sendFriendRequest(result);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request sent')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send friend request')),
      );
    }
  }

  Future<void> _openInviteFriendSheet(String groupId) async {
    final friends = ref.read(friendsProvider);
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add friends first to invite them')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const Text(
                'Invite friend to group',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...friends.map(
                (friend) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(friend.displayName),
                  subtitle: Text(friend.phoneNumber),
                  trailing: const Text(
                    'Invite',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ref
                          .read(socialControllerProvider)
                          .inviteFriendToGroup(
                            groupId: groupId,
                            userId: friend.userId,
                          );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invite sent to ${friend.displayName}'),
                        ),
                      );
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not send group invite'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openGroupDetail(String groupId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _GroupDetailScreen(groupId: groupId)),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GroupDetailScreen extends ConsumerStatefulWidget {
  const _GroupDetailScreen({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<_GroupDetailScreen> {
  late Future<GroupDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = ref
        .read(socialApiRepositoryProvider)
        .fetchGroupDetail(widget.groupId);
  }

  Future<void> _refresh() async {
    final fresh = ref
        .read(socialApiRepositoryProvider)
        .fetchGroupDetail(widget.groupId);
    setState(() => _detailFuture = fresh);
    await fresh;
  }

  Future<void> _inviteMember() async {
    final friends = ref.read(friendsProvider);
    if (friends.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add friends first, then invite to this group.'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const Text(
                'Invite to group',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...friends.map(
                (friend) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(friend.displayName),
                  subtitle: Text(friend.phoneNumber),
                  trailing: const Text(
                    'Invite',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ref
                          .read(socialControllerProvider)
                          .inviteFriendToGroup(
                            groupId: widget.groupId,
                            userId: friend.userId,
                          );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invite sent to ${friend.displayName}'),
                        ),
                      );
                      await _refresh();
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not send group invite'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goCreateSpark() {
    ref.read(bottomTabProvider.notifier).state = 1;
    Navigator.of(context).pop();
  }

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Group',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: FutureBuilder<GroupDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load group details.',
                      style: TextStyle(
                        color: AppColors.errorText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final group = snapshot.data!;
          final isOwner = group.myRole.toUpperCase() == 'OWNER';

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (group.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          group.description,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '${group.members.length} members',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              group.myRole,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _goCreateSpark,
                        icon: const Icon(Icons.flash_on_rounded, size: 16),
                        label: const Text('Create Spark'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _inviteMember,
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 16,
                        ),
                        label: const Text('Add member'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Nudge pending members will be available in next update.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 16,
                  ),
                  label: const Text('Nudge pending'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Members',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...group.members.map(
                  (member) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                member.phoneNumber,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner && member.role.toUpperCase() != 'OWNER')
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Remove member API will be wired in next step.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_remove_alt_1_rounded),
                            color: AppColors.errorText,
                            tooltip: 'Remove member',
                          )
                        else
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
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDim,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Sparks',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'No active sparks for this group yet.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

class _SimpleRowTile extends StatelessWidget {
  const _SimpleRowTile({
    required this.title,
    required this.subtitle,
    required this.trailingText,
    this.onTap,
    this.onTrailingTap,
  });

  final String title;
  final String subtitle;
  final String trailingText;
  final VoidCallback? onTap;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  trailingText,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final IncomingFriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.displayName,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            request.phoneNumber,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupInviteTile extends StatelessWidget {
  const _GroupInviteTile({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  final GroupInviteInboxItem invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invite.groupName,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Invited by ${invite.inviterName}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('Join group'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
