import 'package:flutter/cupertino.dart';
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

class _SocialScreenState extends ConsumerState<SocialScreen> {
  int _tab = 0;
  String _friendQuery = '';
  String _groupQuery = '';
  final _friendSearch = TextEditingController();
  final _groupSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(socialControllerProvider).refreshAll());
  }

  @override
  void dispose() {
    _friendSearch.dispose();
    _groupSearch.dispose();
    super.dispose();
  }

  List<FriendUser> _filteredFriends(List<FriendUser> friends) {
    if (_friendQuery.isEmpty) return friends;
    final q = _friendQuery.toLowerCase();
    return friends
        .where((f) =>
            f.displayName.toLowerCase().contains(q) ||
            f.phoneNumber.contains(q))
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
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'People',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                        letterSpacing: -0.5,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  _HeaderButton(
                    icon: CupertinoIcons.arrow_clockwise,
                    onTap: () =>
                        ref.read(socialControllerProvider).refreshAll(),
                    loading: loading,
                  ),
                  const SizedBox(width: 4),
                  _ProfileButton(
                    badge: totalBadge,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── iOS-style segmented control ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SegmentedControl(
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
                labels: const ['Friends', 'Groups'],
                badges: [friendRequests.length, groupInvites.length],
              ),
            ),

            const SizedBox(height: 8),

            // ── Error banner ──────────────────────────────────────
            if (error != null)
              _ErrorBanner(
                message: _friendlyError(error),
                onDismiss: () =>
                    ref.read(socialErrorProvider.notifier).state = null,
              ),

            // ── Content ───────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _tab == 0
                    ? _FriendsTab(
                        key: const ValueKey('friends'),
                        friends: _filteredFriends(friends),
                        allFriends: friends,
                        friendRequests: friendRequests,
                        query: _friendQuery,
                        searchController: _friendSearch,
                        onQueryChanged: (v) =>
                            setState(() => _friendQuery = v),
                        onAddFriend: _openAddFriendSheet,
                        onAccept: (r) => ref
                            .read(socialControllerProvider)
                            .respondFriendRequest(
                              requestId: r.requestId,
                              decision: InviteDecision.accepted,
                            ),
                        onDecline: (r) => ref
                            .read(socialControllerProvider)
                            .respondFriendRequest(
                              requestId: r.requestId,
                              decision: InviteDecision.declined,
                            ),
                        onUnfriend: _confirmUnfriend,
                      )
                    : _GroupsTab(
                        key: const ValueKey('groups'),
                        groups: _filteredGroups(groups),
                        allGroups: groups,
                        groupInvites: groupInvites,
                        query: _groupQuery,
                        searchController: _groupSearch,
                        onQueryChanged: (v) =>
                            setState(() => _groupQuery = v),
                        onCreateGroup: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CreateGroupScreen()),
                        ),
                        onAcceptInvite: (i) => ref
                            .read(socialControllerProvider)
                            .respondGroupInvite(
                              groupId: i.groupId,
                              inviteId: i.inviteId,
                              decision: InviteDecision.accepted,
                            ),
                        onDeclineInvite: (i) => ref
                            .read(socialControllerProvider)
                            .respondGroupInvite(
                              groupId: i.groupId,
                              inviteId: i.inviteId,
                              decision: InviteDecision.declined,
                            ),
                        onOpenGroup: (g) => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  GroupDetailScreen(groupId: g.groupId)),
                        ),
                        onInviteToGroup: (g) => showInviteToGroupSheet(
                          context,
                          groupId: g.groupId,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(String e) {
    if (e.toLowerCase().contains('network') ||
        e.toLowerCase().contains('socket') ||
        e.toLowerCase().contains('connection')) {
      return 'No connection. Pull down to retry.';
    }
    return 'Something went wrong. Pull down to refresh.';
  }

  Future<void> _openAddFriendSheet() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _BottomSheetCard(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24, 20, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Add friend',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF000000),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter their phone number to send a friend request.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _IosTextField(
                    controller: controller,
                    hint: '+91 98765 43210',
                    keyboardType: TextInputType.phone,
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  _IosButton(
                    label: sending ? 'Sending…' : 'Send request',
                    loading: sending,
                    onTap: sending
                        ? null
                        : () async {
                            final v = controller.text.trim();
                            if (v.isEmpty) return;
                            final clean = v.replaceAll(RegExp(r'[\s\-()]'), '');
                            if (!RegExp(r'^[+]?[0-9]{8,15}$')
                                .hasMatch(clean)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Enter a valid phone number')),
                              );
                              return;
                            }
                            setModal(() => sending = true);
                            try {
                              await ref
                                  .read(socialControllerProvider)
                                  .sendFriendRequest(v);
                              if (!mounted) return;
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Friend request sent!')),
                              );
                            } catch (e) {
                              setModal(() => sending = false);
                              if (!mounted) return;
                              final msg = '$e'.contains('not found')
                                  ? 'No user found with that number.'
                                  : 'Could not send request.';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                  _IosButton(
                    label: 'Cancel',
                    secondary: true,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmUnfriend(FriendUser friend) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(friend.displayName),
        message: const Text('Remove this person from your friends?'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref
                    .read(socialControllerProvider)
                    .unfriend(userId: friend.userId);
                if (!mounted) return;
                _showToast('${friend.displayName} removed');
              } catch (_) {
                if (!mounted) return;
                _showToast('Could not remove friend', error: true);
              }
            },
            child: const Text('Remove friend'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showToast(String msg, {bool error = false}) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Header widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap, this.loading = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          shape: BoxShape.circle,
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              )
            : Icon(icon, size: 15, color: const Color(0xFF3C3C43)),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.badge, required this.onTap});
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0xFFE5E5EA),
          shape: BoxShape.circle,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
              child: Icon(
                CupertinoIcons.person,
                size: 16,
                color: Color(0xFF3C3C43),
              ),
            ),
            if (badge > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented control
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.selected,
    required this.onChanged,
    required this.labels,
    this.badges = const [],
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  final List<int> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(11),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final segWidth = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              // Sliding selection indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: selected * segWidth,
                top: 0,
                bottom: 0,
                width: segWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels
              Row(
                children: List.generate(labels.length, (i) {
                  final isSelected = i == selected;
                  final badge =
                      i < badges.length ? badges[i] : 0;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF000000)
                                    : const Color(0xFF8E8E93),
                                fontFamily: 'Manrope',
                              ),
                              child: Text(labels[i]),
                            ),
                            if (badge > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '$badge',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle_fill,
              size: 15, color: Color(0xFFFF3B30)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Color(0xFFFF3B30),
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(CupertinoIcons.xmark, size: 13,
                color: Color(0xFFFF3B30)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Friends tab
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab({
    super.key,
    required this.friends,
    required this.allFriends,
    required this.friendRequests,
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
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onAddFriend;
  final void Function(IncomingFriendRequest) onAccept;
  final void Function(IncomingFriendRequest) onDecline;
  final void Function(FriendUser) onUnfriend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator.adaptive(
      onRefresh: () => ref.read(socialControllerProvider).refreshAll(),
      child: CustomScrollView(
        slivers: [
          // Add friend CTA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _AddFriendBanner(onTap: onAddFriend),
            ),
          ),

          // Pending requests
          if (friendRequests.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'REQUESTS',
                count: friendRequests.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _FriendRequestCard(
                    request: friendRequests[i],
                    onAccept: () => onAccept(friendRequests[i]),
                    onDecline: () => onDecline(friendRequests[i]),
                  ),
                ),
                childCount: friendRequests.length,
              ),
            ),
          ],

          // Friends list header + search
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'FRIENDS',
              count: allFriends.length,
              showCount: allFriends.isNotEmpty,
            ),
          ),

          if (allFriends.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _SearchBar(
                  controller: searchController,
                  hint: 'Search friends',
                  onChanged: onQueryChanged,
                ),
              ),
            ),

          if (allFriends.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(
                icon: CupertinoIcons.person_2,
                title: 'No friends yet',
                subtitle:
                    'Tap the button above to add\nfriends by phone number.',
              ),
            )
          else if (friends.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(
                icon: CupertinoIcons.search,
                title: 'No results',
                subtitle: 'Try a different name or number.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final f = friends[i];
                  final isLast = i == friends.length - 1;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, isLast ? 32 : 0),
                    child: Dismissible(
                      key: Key(f.userId),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        onUnfriend(f);
                        return false;
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 1),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: _cardBorderRadius(
                              i, friends.length),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.person_badge_minus,
                                color: Colors.white, size: 22),
                            SizedBox(height: 3),
                            Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: _FriendRow(
                        friend: f,
                        isFirst: i == 0,
                        isLast: isLast,
                        onUnfriend: () => onUnfriend(f),
                      ),
                    ),
                  );
                },
                childCount: friends.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Groups tab
// ─────────────────────────────────────────────────────────────────────────────

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab({
    super.key,
    required this.groups,
    required this.allGroups,
    required this.groupInvites,
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
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCreateGroup;
  final void Function(GroupInviteInboxItem) onAcceptInvite;
  final void Function(GroupInviteInboxItem) onDeclineInvite;
  final void Function(SparkGroup) onOpenGroup;
  final void Function(SparkGroup) onInviteToGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator.adaptive(
      onRefresh: () => ref.read(socialControllerProvider).refreshAll(),
      child: CustomScrollView(
        slivers: [
          // Create group CTA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _CreateGroupBanner(onTap: onCreateGroup),
            ),
          ),

          // Group invites
          if (groupInvites.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'INVITES',
                count: groupInvites.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: _GroupInviteCard(
                    invite: groupInvites[i],
                    onAccept: () => onAcceptInvite(groupInvites[i]),
                    onDecline: () => onDeclineInvite(groupInvites[i]),
                  ),
                ),
                childCount: groupInvites.length,
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'YOUR GROUPS',
              count: allGroups.length,
              showCount: allGroups.isNotEmpty,
            ),
          ),

          if (allGroups.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _SearchBar(
                  controller: searchController,
                  hint: 'Search groups',
                  onChanged: onQueryChanged,
                ),
              ),
            ),

          if (allGroups.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(
                icon: CupertinoIcons.person_3,
                title: 'No groups yet',
                subtitle: 'Create a group and invite\nyour friends.',
              ),
            )
          else if (groups.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(
                icon: CupertinoIcons.search,
                title: 'No results',
                subtitle: 'Try a different name.',
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _GroupedCard(
                  children: List.generate(groups.length, (i) {
                    final g = groups[i];
                    return _GroupRow(
                      group: g,
                      isFirst: i == 0,
                      isLast: i == groups.length - 1,
                      onTap: () => onOpenGroup(g),
                      onInvite: () => onInviteToGroup(g),
                    );
                  }),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA Banners
// ─────────────────────────────────────────────────────────────────────────────

class _AddFriendBanner extends StatelessWidget {
  const _AddFriendBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(CupertinoIcons.person_add, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add a friend',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  Text(
                    'Connect by phone number',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

class _CreateGroupBanner extends StatelessWidget {
  const _CreateGroupBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(CupertinoIcons.person_3_fill, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New group',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  Text(
                    'Invite friends and plan sparks together',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List rows
// ─────────────────────────────────────────────────────────────────────────────

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.isFirst,
    required this.isLast,
    required this.onUnfriend,
  });

  final FriendUser friend;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onUnfriend;

  BorderRadius get _radius {
    if (isFirst && isLast) return BorderRadius.circular(14);
    if (isFirst) return const BorderRadius.vertical(top: Radius.circular(14));
    if (isLast) return const BorderRadius.vertical(bottom: Radius.circular(14));
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _radius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _radius,
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                PersonAvatar(name: friend.displayName, radius: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName,
                        style: const TextStyle(
                          fontSize: 16,
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
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.chevron_right,
                    size: 14, color: Color(0xFFC7C7CC)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onInvite,
  });

  final SparkGroup group;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  BorderRadius get _radius {
    if (isFirst && isLast) return BorderRadius.circular(14);
    if (isFirst) return const BorderRadius.vertical(top: Radius.circular(14));
    if (isLast) return const BorderRadius.vertical(bottom: Radius.circular(14));
    return BorderRadius.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 1),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _radius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                PersonAvatar(name: group.name, radius: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF000000),
                          fontFamily: 'Manrope',
                        ),
                      ),
                      Text(
                        '${group.memberCount} member${group.memberCount == 1 ? "" : "s"} · ${group.myRole}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onInvite,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
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
                const SizedBox(width: 8),
                const Icon(CupertinoIcons.chevron_right,
                    size: 14, color: Color(0xFFC7C7CC)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request/invite cards
// ─────────────────────────────────────────────────────────────────────────────

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          PersonAvatar(name: request.displayName, radius: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                    fontFamily: 'Manrope',
                  ),
                ),
                Text(
                  '${request.phoneNumber} · ${_ago(request.createdAt)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniButton(
              label: 'Decline',
              secondary: true,
              onTap: onDecline),
          const SizedBox(width: 6),
          _MiniButton(label: 'Accept', onTap: onAccept),
        ],
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _GroupInviteCard extends StatelessWidget {
  const _GroupInviteCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          PersonAvatar(name: invite.groupName, radius: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.groupName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                    fontFamily: 'Manrope',
                  ),
                ),
                Text(
                  'from ${invite.inviterName}',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniButton(
              label: 'Decline', secondary: true, onTap: onDecline),
          const SizedBox(width: 6),
          _MiniButton(label: 'Join', onTap: onAccept),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Micro-components
// ─────────────────────────────────────────────────────────────────────────────

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.count = 0,
    this.showCount = true,
  });
  final String title;
  final int count;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
      child: Text(
        showCount && count > 0 ? '$title  $count' : title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.3,
          fontFamily: 'Manrope',
        ),
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
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15, color: Color(0xFF000000)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 15,
            color: Color(0xFF8E8E93),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(CupertinoIcons.search,
              size: 16, color: Color(0xFF8E8E93)),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: const Icon(CupertinoIcons.clear_circled_solid,
                      size: 16, color: Color(0xFF8E8E93)),
                )
              : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 9),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: const Color(0xFF8E8E93)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF000000),
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF8E8E93),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.onTap,
    this.secondary = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: secondary
              ? const Color(0xFFE5E5EA)
              : AppColors.accent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: secondary ? const Color(0xFF000000) : Colors.white,
            fontFamily: 'Manrope',
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet helpers
// ─────────────────────────────────────────────────────────────────────────────

class _BottomSheetCard extends StatelessWidget {
  const _BottomSheetCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: child,
    );
  }
}

class _IosTextField extends StatelessWidget {
  const _IosTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        autofocus: autofocus,
        style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: false,
        ),
      ),
    );
  }
}

class _IosButton extends StatelessWidget {
  const _IosButton({
    required this.label,
    this.onTap,
    this.secondary = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool secondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: secondary
              ? const Color(0xFFE5E5EA)
              : (onTap == null ? AppColors.accent.withValues(alpha: 0.5) : AppColors.accent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        secondary ? const Color(0xFF000000) : Colors.white,
                    fontFamily: 'Manrope',
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

BorderRadius _cardBorderRadius(int i, int total) {
  const r = Radius.circular(14);
  const z = Radius.zero;
  if (total == 1) return const BorderRadius.all(r);
  if (i == 0) return const BorderRadius.only(topLeft: r, topRight: r);
  if (i == total - 1) {
    return const BorderRadius.only(bottomLeft: r, bottomRight: r);
  }
  return BorderRadius.zero;
}
