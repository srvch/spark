import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../domain/social.dart';
import '../controllers/social_controller.dart';
import '../widgets/invite_to_group_sheet.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _friendQuery = '';
  String _groupQuery = '';
  final _friendSearch = TextEditingController();
  final _groupSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(socialControllerProvider).refreshAll());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _friendSearch.dispose();
    _groupSearch.dispose();
    super.dispose();
  }

  List<FriendUser> _filteredFriends(List<FriendUser> friends) {
    if (_friendQuery.isEmpty) return friends;
    final q = _friendQuery.toLowerCase();
    return friends
        .where(
          (f) =>
              f.displayName.toLowerCase().contains(q) ||
              f.phoneNumber.contains(q),
        )
        .toList();
  }

  List<SparkGroup> _filteredGroups(List<SparkGroup> groups) {
    if (_groupQuery.isEmpty) return groups;
    final q = _groupQuery.toLowerCase();
    return groups.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(socialLoadingProvider);
    final error = ref.watch(socialErrorProvider);
    final friends = ref.watch(friendsProvider);
    final friendRequests = ref.watch(incomingFriendRequestsProvider);
    final groups = ref.watch(groupsProvider);
    final groupInvites = ref.watch(incomingGroupInvitesProvider);

    final totalBadge = friendRequests.length + groupInvites.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              badge: totalBadge,
              onProfileTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              onRefresh: () =>
                  ref.read(socialControllerProvider).refreshAll(),
            ),
            _TabBar(controller: _tabs),
            if (error != null)
              _ErrorBanner(
                message: _friendlyError(error),
                onDismiss: () =>
                    ref.read(socialErrorProvider.notifier).state = null,
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _FriendsTab(
                    friends: _filteredFriends(friends),
                    allFriends: friends,
                    friendRequests: friendRequests,
                    loading: loading,
                    query: _friendQuery,
                    searchController: _friendSearch,
                    onQueryChanged: (v) =>
                        setState(() => _friendQuery = v),
                    onAddFriend: _openAddFriendDialog,
                    onAccept: (r) =>
                        ref.read(socialControllerProvider).respondFriendRequest(
                          requestId: r.requestId,
                          decision: InviteDecision.accepted,
                        ),
                    onDecline: (r) =>
                        ref.read(socialControllerProvider).respondFriendRequest(
                          requestId: r.requestId,
                          decision: InviteDecision.declined,
                        ),
                    onUnfriend: _confirmUnfriend,
                  ),
                  _GroupsTab(
                    groups: _filteredGroups(groups),
                    allGroups: groups,
                    groupInvites: groupInvites,
                    loading: loading,
                    query: _groupQuery,
                    searchController: _groupSearch,
                    onQueryChanged: (v) =>
                        setState(() => _groupQuery = v),
                    onCreateGroup: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateGroupScreen(),
                      ),
                    ),
                    onAcceptInvite: (i) =>
                        ref.read(socialControllerProvider).respondGroupInvite(
                          groupId: i.groupId,
                          inviteId: i.inviteId,
                          decision: InviteDecision.accepted,
                        ),
                    onDeclineInvite: (i) =>
                        ref.read(socialControllerProvider).respondGroupInvite(
                          groupId: i.groupId,
                          inviteId: i.inviteId,
                          decision: InviteDecision.declined,
                        ),
                    onOpenGroup: (g) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(groupId: g.groupId),
                      ),
                    ),
                    onInviteToGroup: (g) => showInviteToGroupSheet(
                      context,
                      groupId: g.groupId,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(String error) {
    if (error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('socket') ||
        error.toLowerCase().contains('connection')) {
      return 'Could not connect. Check your server and try again.';
    }
    return 'Something went wrong. Pull down to refresh.';
  }

  Future<void> _openAddFriendDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add friend by phone'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(hintText: '+91 98XXXXXX10'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter a phone number';
              final clean = v.replaceAll(RegExp(r'[\s\-()]'), '');
              if (!RegExp(r'^[+]?[0-9]{8,15}$').hasMatch(clean)) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (!mounted || result == null || result.isEmpty) return;
    try {
      await ref.read(socialControllerProvider).sendFriendRequest(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = '$e'.contains('not found')
          ? 'No user found with that number.'
          : 'Could not send request. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _confirmUnfriend(FriendUser friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          'Remove ${friend.displayName} from your friends? You can always add them back.',
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
    try {
      await ref.read(socialControllerProvider).unfriend(userId: friend.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${friend.displayName} removed from friends')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove friend. Try again.')),
      );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.badge,
    required this.onProfileTap,
    required this.onRefresh,
  });

  final int badge;
  final VoidCallback onProfileTap;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'People',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'Manrope',
              ),
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textSecondary,
            tooltip: 'Refresh',
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onProfileTap,
                icon: const Icon(Icons.person_outline_rounded),
                color: AppColors.textPrimary,
                tooltip: 'Your profile',
              ),
              if (badge > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.action,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          fontFamily: 'Manrope',
        ),
        tabs: const [Tab(text: 'Friends'), Tab(text: 'Groups')],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.errorSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorText.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.errorText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.errorText,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 14),
            color: AppColors.errorText,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Manrope',
            ),
          ),
          if (action != null && onAction != null) ...[
            const Spacer(),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  action!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.sub});
  final IconData icon;
  final String message;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({
    required this.friends,
    required this.allFriends,
    required this.friendRequests,
    required this.loading,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onAddFriend,
    required this.onAccept,
    required this.onDecline,
    required this.onUnfriend,
  });

  final List<FriendUser> friends;
  final List<FriendUser> allFriends;
  final List<IncomingFriendRequest> friendRequests;
  final bool loading;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAddFriend;
  final void Function(IncomingFriendRequest) onAccept;
  final void Function(IncomingFriendRequest) onDecline;
  final void Function(FriendUser) onUnfriend;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async =>
          ProviderScope.containerOf(context)
              .read(socialControllerProvider)
              .refreshAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (friendRequests.isNotEmpty) ...[
            _SectionLabel(title: 'Incoming requests'),
            ...friendRequests.map(
              (r) => _FriendRequestTile(
                request: r,
                onAccept: () => onAccept(r),
                onDecline: () => onDecline(r),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionLabel(
            title: 'Friends  ${allFriends.isNotEmpty ? "(${allFriends.length})" : ""}',
            action: '+ Add by phone',
            onAction: onAddFriend,
          ),
          if (allFriends.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SearchBar(
                controller: searchController,
                hint: 'Search friends',
                onChanged: onQueryChanged,
              ),
            ),
          if (allFriends.isEmpty)
            _EmptyState(
              icon: Icons.people_outline_rounded,
              message: 'No friends yet',
              sub: 'Add friends by their phone number',
            )
          else if (friends.isEmpty)
            _EmptyState(
              icon: Icons.search_off_rounded,
              message: 'No matches',
              sub: 'Try a different name or number',
            )
          else
            ...friends.map(
              (f) => _FriendTile(
                friend: f,
                onUnfriend: () => onUnfriend(f),
              ),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({
    required this.groups,
    required this.allGroups,
    required this.groupInvites,
    required this.loading,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onCreateGroup,
    required this.onAcceptInvite,
    required this.onDeclineInvite,
    required this.onOpenGroup,
    required this.onInviteToGroup,
  });

  final List<SparkGroup> groups;
  final List<SparkGroup> allGroups;
  final List<GroupInviteInboxItem> groupInvites;
  final bool loading;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCreateGroup;
  final void Function(GroupInviteInboxItem) onAcceptInvite;
  final void Function(GroupInviteInboxItem) onDeclineInvite;
  final void Function(SparkGroup) onOpenGroup;
  final void Function(SparkGroup) onInviteToGroup;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async =>
          ProviderScope.containerOf(context)
              .read(socialControllerProvider)
              .refreshAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (groupInvites.isNotEmpty) ...[
            _SectionLabel(title: 'Group invites'),
            ...groupInvites.map(
              (i) => _GroupInviteTile(
                invite: i,
                onAccept: () => onAcceptInvite(i),
                onDecline: () => onDeclineInvite(i),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionLabel(
            title: 'Your groups  ${allGroups.isNotEmpty ? "(${allGroups.length})" : ""}',
            action: '+ Create group',
            onAction: onCreateGroup,
          ),
          if (allGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SearchBar(
                controller: searchController,
                hint: 'Search groups',
                onChanged: onQueryChanged,
              ),
            ),
          if (allGroups.isEmpty)
            _EmptyState(
              icon: Icons.group_outlined,
              message: 'No groups yet',
              sub: 'Create a group and invite your friends',
            )
          else if (groups.isEmpty)
            _EmptyState(
              icon: Icons.search_off_rounded,
              message: 'No matches',
            )
          else
            ...groups.map(
              (g) => _GroupTile(
                group: g,
                onTap: () => onOpenGroup(g),
                onInvite: () => onInviteToGroup(g),
              ),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onUnfriend});

  final FriendUser friend;
  final VoidCallback onUnfriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        leading: PersonAvatar(name: friend.displayName, radius: 20),
        title: Text(
          friend.displayName,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          friend.phoneNumber,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
          onSelected: (v) {
            if (v == 'unfriend') onUnfriend();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'unfriend',
              child: Row(
                children: [
                  Icon(
                    Icons.person_remove_outlined,
                    size: 16,
                    color: AppColors.errorText,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Remove friend',
                    style: TextStyle(color: AppColors.errorText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.onTap,
    required this.onInvite,
  });

  final SparkGroup group;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              PersonAvatar(name: group.name, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${group.memberCount} member${group.memberCount == 1 ? "" : "s"} · ${group.myRole}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onInvite,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text(
                  'Invite',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
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
    final since = _timeAgo(request.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          PersonAvatar(name: request.displayName, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${request.phoneNumber} · $since',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onDecline,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text(
              'Decline',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              backgroundColor: AppColors.accent,
            ),
            child: const Text(
              'Accept',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          PersonAvatar(name: invite.groupName, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.groupName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'from ${invite.inviterName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onDecline,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text(
              'Decline',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              backgroundColor: AppColors.accent,
            ),
            child: const Text('Join', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
