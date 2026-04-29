import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_privacy.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../domain/social.dart';
import '../controllers/social_controller.dart';
import '../widgets/contact_import_sheet.dart';
import '../widgets/invite_to_group_sheet.dart';
import 'create_group_screen.dart';
import 'friend_profile_screen.dart';
import 'group_detail_screen.dart';
import 'qr_code_screen.dart';

// ─── Main Screen ─────────────────────────────────────────────────────────────

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
  bool _showSentRequests = false;

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
    var list = friends;
    if (_friendQuery.isNotEmpty) {
      final q = _friendQuery.toLowerCase();
      list =
          list
              .where(
                (f) =>
                    f.displayName.toLowerCase().contains(q) ||
                    f.phoneNumber.contains(q),
              )
              .toList();
    }
    final sort = ref.read(friendSortProvider);
    if (sort == FriendSort.alphabetical) {
      list = [...list]..sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return list;
  }

  List<SparkGroup> _filteredGroups(List<SparkGroup> groups) {
    var list = groups;
    if (_groupQuery.isNotEmpty) {
      final q = _groupQuery.toLowerCase();
      list = list.where((g) => g.name.toLowerCase().contains(q)).toList();
    }
    final sort = ref.read(groupSortProvider);
    if (sort == GroupSort.alphabetical) {
      list = [...list]..sort((a, b) => a.name.compareTo(b.name));
    } else if (sort == GroupSort.ownerFirst) {
      list = [...list]..sort((a, b) {
        if (a.isOwner && !b.isOwner) return -1;
        if (!a.isOwner && b.isOwner) return 1;
        return 0;
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(socialLoadingProvider);
    final error = ref.watch(socialErrorProvider);
    final friends = ref.watch(friendsProvider);
    final friendRequests = ref.watch(incomingFriendRequestsProvider);
    final outgoingRequests = ref.watch(outgoingFriendRequestsProvider);
    final suggestions = ref.watch(friendSuggestionsProvider);
    final groups = ref.watch(groupsProvider);
    final groupInvites = ref.watch(incomingGroupInvitesProvider);
    final myAvailability = ref.watch(myAvailabilityProvider);
    final totalBadge = friendRequests.length + groupInvites.length;
    final friendSort = ref.watch(friendSortProvider);
    final groupSort = ref.watch(groupSortProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: AppColors.cardDivider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(bottomTabProvider.notifier).state = 0;
                    },
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'People',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.7,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  _HeaderButton(
                    icon: CupertinoIcons.qrcode,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => const QrCodeScreen(
                                userId: 'me',
                                name: 'My Profile',
                              ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  _HeaderButton(
                    icon: CupertinoIcons.arrow_clockwise,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(socialControllerProvider).refreshAll();
                    },
                    loading: loading,
                  ),
                  const SizedBox(width: 6),
                  _ProfileButton(
                    badge: totalBadge,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SegmentedControl(
                selected: _tab,
                onChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _tab = i);
                },
                labels: const ['Friends', 'Groups'],
                badges: [friendRequests.length, groupInvites.length],
              ),
            ),

            const SizedBox(height: 8),

            if (error != null)
              _ErrorBanner(
                message: _friendlyError(error),
                onDismiss:
                    () => ref.read(socialErrorProvider.notifier).state = null,
              ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child:
                    _tab == 0
                        ? _FriendsTab(
                          key: const ValueKey('friends'),
                          loading: loading,
                          friends: _filteredFriends(friends),
                          allFriends: friends,
                          friendRequests: friendRequests,
                          outgoingRequests: outgoingRequests,
                          suggestions: suggestions,
                          myAvailability: myAvailability,
                          sort: friendSort,
                          showSentRequests: _showSentRequests,
                          query: _friendQuery,
                          searchController: _friendSearch,
                          onQueryChanged:
                              (v) => setState(() => _friendQuery = v),
                          onSortChanged: (s) {
                            HapticFeedback.lightImpact();
                            ref.read(friendSortProvider.notifier).state = s;
                          },
                          onToggleSentRequests:
                              () => setState(
                                () => _showSentRequests = !_showSentRequests,
                              ),
                          onAddFriend: _openAddFriendSheet,
                          onAccept: (r) {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(socialControllerProvider)
                                .respondFriendRequest(
                                  requestId: r.requestId,
                                  decision: InviteDecision.accepted,
                                );
                          },
                          onDecline: (r) {
                            HapticFeedback.lightImpact();
                            ref
                                .read(socialControllerProvider)
                                .respondFriendRequest(
                                  requestId: r.requestId,
                                  decision: InviteDecision.declined,
                                );
                          },
                          onCancelOutgoing: (r) {
                            HapticFeedback.lightImpact();
                            ref
                                .read(socialControllerProvider)
                                .cancelFriendRequest(requestId: r.requestId);
                          },
                          onAddSuggestion: (s) {
                            HapticFeedback.lightImpact();
                            _openAddFriendSheetWithPhone(s.phoneNumber);
                          },
                          onUnfriend: _showFriendActionSheet,
                          onOpenFriend:
                              (f) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => FriendProfileScreen(friend: f),
                                ),
                              ),
                          onToggleAvailability: () {
                            HapticFeedback.mediumImpact();
                            final current = ref.read(myAvailabilityProvider);
                            ref
                                .read(socialControllerProvider)
                                .setAvailability(
                                  current == 'OPEN' ? 'NONE' : 'OPEN',
                                );
                          },
                          onImportContacts: _openContactImport,
                        )
                        : _GroupsTab(
                          key: const ValueKey('groups'),
                          loading: loading,
                          groups: _filteredGroups(groups),
                          allGroups: groups,
                          groupInvites: groupInvites,
                          sort: groupSort,
                          query: _groupQuery,
                          searchController: _groupSearch,
                          onQueryChanged:
                              (v) => setState(() => _groupQuery = v),
                          onSortChanged: (s) {
                            HapticFeedback.lightImpact();
                            ref.read(groupSortProvider.notifier).state = s;
                          },
                          onCreateGroup: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateGroupScreen(),
                              ),
                            );
                          },
                          onAcceptInvite: (i) {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(socialControllerProvider)
                                .respondGroupInvite(
                                  groupId: i.groupId,
                                  inviteId: i.inviteId,
                                  decision: InviteDecision.accepted,
                                );
                          },
                          onDeclineInvite: (i) {
                            HapticFeedback.lightImpact();
                            ref
                                .read(socialControllerProvider)
                                .respondGroupInvite(
                                  groupId: i.groupId,
                                  inviteId: i.inviteId,
                                  decision: InviteDecision.declined,
                                );
                          },
                          onOpenGroup:
                              (g) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          GroupDetailScreen(groupId: g.groupId),
                                ),
                              ),
                          onInviteToGroup:
                              (g) => showInviteToGroupSheet(
                                context,
                                groupId: g.groupId,
                              ),
                          onArchiveGroup: (g) {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(socialControllerProvider)
                                .archiveGroup(groupId: g.groupId);
                          },
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
    await _openAddFriendSheetWithPhone(null);
  }

  Future<void> _openAddFriendSheetWithPhone(String? prefill) async {
    final controller = TextEditingController(text: prefill ?? '');
    final messageCtrl = TextEditingController();
    var sending = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setModal) => _BottomSheetCard(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      20,
                      24,
                      MediaQuery.of(ctx).viewInsets.bottom + 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter their phone number to send a request.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _IosTextField(
                          controller: controller,
                          hint: '+91 98765 43210',
                          keyboardType: TextInputType.phone,
                          autofocus: prefill == null,
                        ),
                        const SizedBox(height: 10),
                        _IosTextField(
                          controller: messageCtrl,
                          hint: 'Add a message (optional)',
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 20),
                        _IosButton(
                          label: sending ? 'Sending…' : 'Send request',
                          loading: sending,
                          onTap:
                              sending
                                  ? null
                                  : () async {
                                    final v = controller.text.trim();
                                    if (v.isEmpty) return;
                                    final clean = v.replaceAll(
                                      RegExp(r'[\s\-()]'),
                                      '',
                                    );
                                    if (!RegExp(
                                      r'^[+]?[0-9]{8,15}$',
                                    ).hasMatch(clean)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Enter a valid phone number',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setModal(() => sending = true);
                                    try {
                                      await ref
                                          .read(socialControllerProvider)
                                          .sendFriendRequest(
                                            v,
                                            message:
                                                messageCtrl.text.trim().isEmpty
                                                    ? null
                                                    : messageCtrl.text.trim(),
                                          );
                                      if (!mounted) return;
                                      Navigator.of(ctx).pop();
                                      HapticFeedback.mediumImpact();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Friend request sent!'),
                                        ),
                                      );
                                    } catch (e) {
                                      setModal(() => sending = false);
                                      if (!mounted) return;
                                      final msg =
                                          '$e'.contains('not found')
                                              ? 'No user found with that number.'
                                              : 'Could not send request.';
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                    }
                                  },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Color(0xFFE5E5EA)),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Color(0xFFE5E5EA)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _IosButton(
                          label: 'Choose from contacts',
                          secondary: true,
                          icon: CupertinoIcons.person_crop_circle_badge_plus,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            showContactImportSheet(context);
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
    );
  }

  Future<void> _openContactImport() async {
    await showContactImportSheet(context);
  }

  Future<void> _showFriendActionSheet(FriendUser friend) async {
    HapticFeedback.lightImpact();
    await showCupertinoModalPopup<void>(
      context: context,
      builder:
          (ctx) => CupertinoActionSheet(
            title: Text(friend.displayName),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FriendProfileScreen(friend: friend),
                    ),
                  );
                },
                child: const Text('View profile'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => QrCodeScreen(
                            userId: friend.userId,
                            name: friend.displayName,
                          ),
                    ),
                  );
                },
                child: const Text('Share profile'),
              ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _confirmUnfriend(friend);
                },
                child: const Text('Remove friend'),
              ),
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _confirmBlock(friend);
                },
                child: const Text('Block'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ),
    );
  }

  Future<void> _confirmUnfriend(FriendUser friend) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder:
          (ctx) => CupertinoActionSheet(
            title: Text(friend.displayName),
            message: const Text('Remove this person from your friends?'),
            actions: [
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  HapticFeedback.mediumImpact();
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

  Future<void> _confirmBlock(FriendUser friend) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder:
          (ctx) => CupertinoActionSheet(
            title: Text(friend.displayName),
            message: const Text('Block this person?'),
            actions: [
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  HapticFeedback.mediumImpact();
                  try {
                    await ref
                        .read(socialControllerProvider)
                        .blockUser(userId: friend.userId);
                    if (!mounted) return;
                    _showToast('${friend.displayName} blocked');
                  } catch (_) {
                    if (!mounted) return;
                    _showToast('Could not block user', error: true);
                  }
                },
                child: const Text('Block'),
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

  void _toast(String msg) => _showToast(msg);
}

// ─────────────────────────────────────────────────────────────────────────────
// Friends Tab
// ─────────────────────────────────────────────────────────────────────────────

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab({
    super.key,
    required this.loading,
    required this.friends,
    required this.allFriends,
    required this.friendRequests,
    required this.outgoingRequests,
    required this.suggestions,
    required this.myAvailability,
    required this.sort,
    required this.showSentRequests,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onToggleSentRequests,
    required this.onAddFriend,
    required this.onAccept,
    required this.onDecline,
    required this.onCancelOutgoing,
    required this.onAddSuggestion,
    required this.onUnfriend,
    required this.onOpenFriend,
    required this.onToggleAvailability,
    required this.onImportContacts,
  });

  final bool loading;
  final List<FriendUser> friends;
  final List<FriendUser> allFriends;
  final List<IncomingFriendRequest> friendRequests;
  final List<OutgoingFriendRequest> outgoingRequests;
  final List<FriendSuggestion> suggestions;
  final String myAvailability;
  final FriendSort sort;
  final bool showSentRequests;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FriendSort> onSortChanged;
  final VoidCallback onToggleSentRequests;
  final VoidCallback onAddFriend;
  final ValueChanged<IncomingFriendRequest> onAccept;
  final ValueChanged<IncomingFriendRequest> onDecline;
  final ValueChanged<OutgoingFriendRequest> onCancelOutgoing;
  final ValueChanged<FriendSuggestion> onAddSuggestion;
  final ValueChanged<FriendUser> onUnfriend;
  final ValueChanged<FriendUser> onOpenFriend;
  final VoidCallback onToggleAvailability;
  final VoidCallback onImportContacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFirstTime =
        allFriends.isEmpty &&
        friendRequests.isEmpty &&
        outgoingRequests.isEmpty &&
        !loading;

    if (loading && allFriends.isEmpty) {
      return const _SkeletonList();
    }

    if (isFirstTime) {
      return _OnboardingEmpty(
        onAddFriend: onAddFriend,
        onImport: onImportContacts,
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: () => ref.read(socialControllerProvider).refreshAll(),
      child: CustomScrollView(
        slivers: [
          // ── Search ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _SearchBar(
                controller: searchController,
                hint: 'Search friends',
                onChanged: onQueryChanged,
              ),
            ),
          ),

          // ── Who's free strip ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _WhosFreeBanner(
                myAvailability: myAvailability,
                availableFriends:
                    allFriends.where((f) => f.isAvailable).toList(),
                onToggle: onToggleAvailability,
              ),
            ),
          ),

          // ── Add friend CTA ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _CtaBanner(
                icon: CupertinoIcons.person_add_solid,
                title: 'Add a friend',
                subtitle: 'by phone number or share your QR code',
                color: AppColors.accent,
                onTap: onAddFriend,
              ),
            ),
          ),

          // ── Incoming requests ────────────────────────────────────────────
          if (friendRequests.isNotEmpty) ...[
            _sectionHeader(
              '${friendRequests.length} PENDING REQUEST${friendRequests.length > 1 ? 'S' : ''}',
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final r = friendRequests[i];
                  final isFirst = i == 0;
                  final isLast = i == friendRequests.length - 1;
                  return _RequestCard(
                    request: r,
                    isFirst: isFirst,
                    isLast: isLast,
                    onAccept: () => onAccept(r),
                    onDecline: () => onDecline(r),
                  );
                }, childCount: friendRequests.length),
              ),
            ),
          ],

          // ── Sent requests ─────────────────────────────────────────────────
          if (outgoingRequests.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SentRequestsSection(
                  requests: outgoingRequests,
                  expanded: showSentRequests,
                  onToggle: onToggleSentRequests,
                  onCancel: onCancelOutgoing,
                ),
              ),
            ),

          // ── Suggestions ───────────────────────────────────────────────────
          if (suggestions.isNotEmpty && query.isEmpty) ...[
            _sectionHeader('YOU MIGHT KNOW'),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _SuggestionsRow(
                  suggestions: suggestions,
                  onAdd: onAddSuggestion,
                ),
              ),
            ),
          ],

          // ── Sort control ──────────────────────────────────────────────────
          if (allFriends.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'FRIENDS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _SortPill(
                      label: 'Recent',
                      selected: sort == FriendSort.recent,
                      onTap: () => onSortChanged(FriendSort.recent),
                    ),
                    const SizedBox(width: 6),
                    _SortPill(
                      label: 'A–Z',
                      selected: sort == FriendSort.alphabetical,
                      onTap: () => onSortChanged(FriendSort.alphabetical),
                    ),
                  ],
                ),
              ),
            ),

          // ── Friends list ──────────────────────────────────────────────────
          if (allFriends.isEmpty && !loading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _CtaBanner(
                  icon: CupertinoIcons.person_2,
                  title: 'No friends yet',
                  subtitle: 'Import contacts or share your QR code',
                  color: const Color(0xFF8E8E93),
                  onTap: onImportContacts,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final f = friends[i];
                  final isFirst = i == 0;
                  final isLast = i == friends.length - 1;
                  return Dismissible(
                    key: ValueKey(f.userId),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      HapticFeedback.mediumImpact();
                      onUnfriend(f);
                      return false;
                    },
                    background: Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 1),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: _cardBorderRadius(i, friends.length),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.person_badge_minus,
                            color: Colors.white,
                            size: 22,
                          ),
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
                      isFirst: isFirst,
                      isLast: isLast,
                      onTap: () => onOpenFriend(f),
                      onUnfriend: () => onUnfriend(f),
                    ),
                  );
                }, childCount: friends.length),
              ),
            ),

          // ── Import contacts CTA ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: GestureDetector(
                onTap: onImportContacts,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF34C759,
                          ).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.person_crop_circle_badge_plus,
                          size: 16,
                          color: Color(0xFF34C759),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Find friends from contacts',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: Color(0xFFC7C7CC),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Groups Tab
// ─────────────────────────────────────────────────────────────────────────────

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab({
    super.key,
    required this.loading,
    required this.groups,
    required this.allGroups,
    required this.groupInvites,
    required this.sort,
    required this.query,
    required this.searchController,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onCreateGroup,
    required this.onAcceptInvite,
    required this.onDeclineInvite,
    required this.onOpenGroup,
    required this.onInviteToGroup,
    required this.onArchiveGroup,
  });

  final bool loading;
  final List<SparkGroup> groups;
  final List<SparkGroup> allGroups;
  final List<GroupInviteInboxItem> groupInvites;
  final GroupSort sort;
  final String query;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<GroupSort> onSortChanged;
  final VoidCallback onCreateGroup;
  final ValueChanged<GroupInviteInboxItem> onAcceptInvite;
  final ValueChanged<GroupInviteInboxItem> onDeclineInvite;
  final ValueChanged<SparkGroup> onOpenGroup;
  final ValueChanged<SparkGroup> onInviteToGroup;
  final ValueChanged<SparkGroup> onArchiveGroup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (loading && allGroups.isEmpty) {
      return const _SkeletonList();
    }

    return RefreshIndicator.adaptive(
      onRefresh: () => ref.read(socialControllerProvider).refreshAll(),
      child: CustomScrollView(
        slivers: [
          // ── Search ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _SearchBar(
                controller: searchController,
                hint: 'Search groups',
                onChanged: onQueryChanged,
              ),
            ),
          ),

          // ── Create CTA ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _CtaBanner(
                icon: CupertinoIcons.person_3_fill,
                title: 'New group',
                subtitle: 'Create a group to plan sparks together',
                color: AppColors.accent,
                onTap: onCreateGroup,
              ),
            ),
          ),

          // ── Incoming group invites ────────────────────────────────────
          if (groupInvites.isNotEmpty) ...[
            _sectionHeader(
              '${groupInvites.length} GROUP INVITE${groupInvites.length > 1 ? 'S' : ''}',
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final inv = groupInvites[i];
                  final isFirst = i == 0;
                  final isLast = i == groupInvites.length - 1;
                  return _GroupInviteCard(
                    invite: inv,
                    isFirst: isFirst,
                    isLast: isLast,
                    onAccept: () => onAcceptInvite(inv),
                    onDecline: () => onDeclineInvite(inv),
                  );
                }, childCount: groupInvites.length),
              ),
            ),
          ],

          // ── Sort control ──────────────────────────────────────────────
          if (allGroups.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'GROUPS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _SortPill(
                      label: 'Recent',
                      selected: sort == GroupSort.recent,
                      onTap: () => onSortChanged(GroupSort.recent),
                    ),
                    const SizedBox(width: 6),
                    _SortPill(
                      label: 'A–Z',
                      selected: sort == GroupSort.alphabetical,
                      onTap: () => onSortChanged(GroupSort.alphabetical),
                    ),
                    const SizedBox(width: 6),
                    _SortPill(
                      label: 'Owner',
                      selected: sort == GroupSort.ownerFirst,
                      onTap: () => onSortChanged(GroupSort.ownerFirst),
                    ),
                  ],
                ),
              ),
            ),

          // ── Groups list ───────────────────────────────────────────────
          if (allGroups.isEmpty && !loading)
            _sectionHeader('NO GROUPS YET')
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final g = groups[i];
                  final isFirst = i == 0;
                  final isLast = i == groups.length - 1;
                  return Dismissible(
                    key: ValueKey(g.groupId),
                    direction:
                        g.isOwner
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                    confirmDismiss: (_) async {
                      HapticFeedback.mediumImpact();
                      onArchiveGroup(g);
                      return false;
                    },
                    background: Container(
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 1),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E8E93),
                        borderRadius: _cardBorderRadius(i, groups.length),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.archivebox,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Archive',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: _GroupRow(
                      group: g,
                      isFirst: isFirst,
                      isLast: isLast,
                      onTap: () => onOpenGroup(g),
                      onInvite: () => onInviteToGroup(g),
                    ),
                  );
                }, childCount: groups.length),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Special feature widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WhosFreeBanner extends StatelessWidget {
  const _WhosFreeBanner({
    required this.myAvailability,
    required this.availableFriends,
    required this.onToggle,
  });
  final String myAvailability;
  final List<FriendUser> availableFriends;
  final VoidCallback onToggle;

  bool get _isOpen => myAvailability == 'OPEN';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isOpen ? AppColors.accent : const Color(0xFFD1D1D6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isOpen
                      ? 'You\'re open to plans'
                      : 'Tell friends you\'re free',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Manrope',
                  ),
                ),
              ),
              CupertinoSwitch(
                value: _isOpen,
                onChanged: (_) => onToggle(),
                activeTrackColor: AppColors.accent,
                trackColor: const Color(0xFFE5E5EA),
              ),
            ],
          ),
          if (availableFriends.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int i = 0; i < availableFriends.length.clamp(0, 5); i++)
                  Padding(
                    padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                    child: PersonAvatar(
                      name: availableFriends[i].displayName,
                      radius: 14,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    availableFriends.length == 1
                        ? '${availableFriends[0].displayName} is free'
                        : '${availableFriends.length} friends are open to plans',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF34C759),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SentRequestsSection extends StatelessWidget {
  const _SentRequestsSection({
    required this.requests,
    required this.expanded,
    required this.onToggle,
    required this.onCancel,
  });
  final List<OutgoingFriendRequest> requests;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<OutgoingFriendRequest> onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.clock,
                    size: 16,
                    color: Color(0xFF8E8E93),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${requests.length} sent request${requests.length > 1 ? 's' : ''} pending',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 13,
                    color: const Color(0xFF8E8E93),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            for (int i = 0; i < requests.length; i++) ...[
              const Divider(
                height: 1,
                thickness: 0.5,
                indent: 14,
                color: Color(0xFFE5E5EA),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    PersonAvatar(name: requests[i].displayName, radius: 17),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            requests[i].displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontFamily: 'Manrope',
                            ),
                          ),
                          Text(
                            requests[i].phoneNumber,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => onCancel(requests[i]),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _SuggestionsRow extends StatelessWidget {
  const _SuggestionsRow({required this.suggestions, required this.onAdd});
  final List<FriendSuggestion> suggestions;
  final ValueChanged<FriendSuggestion> onAdd;

  @override
  Widget build(BuildContext context) {
    final limited = suggestions.take(5).toList();
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: limited.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = limited[i];
          return Container(
            width: 110,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PersonAvatar(name: s.displayName, radius: 24),
                const SizedBox(height: 6),
                Text(
                  s.displayName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Manrope',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${s.mutualGroupCount} mutual',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => onAdd(s),
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _OnboardingEmpty extends StatelessWidget {
  const _OnboardingEmpty({required this.onAddFriend, required this.onImport});
  final VoidCallback onAddFriend;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.person_2_fill,
                size: 36,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to People',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
                fontFamily: 'Manrope',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Add friends so you can invite them to sparks and create groups for your crews.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF8E8E93),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            _OnboardingStep(
              icon: CupertinoIcons.phone_fill,
              title: 'Add by phone number',
              subtitle: 'Send a friend request to anyone on Spark.',
              onTap: onAddFriend,
              cta: 'Add friend',
              primary: true,
            ),
            const SizedBox(height: 12),
            _OnboardingStep(
              icon: CupertinoIcons.person_crop_circle_badge_plus,
              title: 'Import from contacts',
              subtitle: 'See which of your contacts are on Spark.',
              onTap: onImport,
              cta: 'Import contacts',
            ),
            const SizedBox(height: 12),
            _OnboardingStep(
              icon: CupertinoIcons.qrcode,
              title: 'Share your QR code',
              subtitle: 'Let people add you instantly in person.',
              onTap:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => const QrCodeScreen(
                            userId: 'me',
                            name: 'My Profile',
                          ),
                    ),
                  ),
              cta: 'My QR code',
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.cta,
    this.primary = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String cta;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primary ? AppColors.accent : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  primary
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: primary ? Colors.white : AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: primary ? Colors.white : const Color(0xFF000000),
                    fontFamily: 'Manrope',
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        primary
                            ? Colors.white.withValues(alpha: 0.8)
                            : const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: primary ? Colors.white : AppColors.accent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                cta,
                style: TextStyle(
                  color: primary ? AppColors.accent : Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Manrope',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton Loading
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
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
      begin: 0.35,
      end: 0.85,
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
          (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              _SkeletonCard(height: 44, opacity: _anim.value),
              const SizedBox(height: 10),
              _SkeletonCard(height: 76, opacity: _anim.value),
              const SizedBox(height: 14),
              _SkeletonCard(
                height: 14,
                width: 80,
                opacity: _anim.value,
                margin: const EdgeInsets.only(left: 4, bottom: 6),
              ),
              for (int i = 0; i < 5; i++)
                _SkeletonCard(
                  height: 56,
                  opacity: _anim.value,
                  radius:
                      i == 0
                          ? const BorderRadius.vertical(
                            top: Radius.circular(14),
                          )
                          : i == 4
                          ? const BorderRadius.vertical(
                            bottom: Radius.circular(14),
                          )
                          : BorderRadius.zero,
                  margin: EdgeInsets.only(bottom: i < 4 ? 1 : 0),
                ),
            ],
          ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.height,
    required this.opacity,
    this.width,
    this.radius,
    this.margin,
  });
  final double height;
  final double opacity;
  final double? width;
  final BorderRadius? radius;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        height: height,
        width: width,
        margin: margin,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: radius ?? BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Row Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isFirst,
    required this.isLast,
    required this.onAccept,
    required this.onDecline,
  });
  final IncomingFriendRequest request;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: _radius,
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
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Manrope',
                  ),
                ),
                Text(
                  request.phoneNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                if (request.message != null && request.message!.isNotEmpty)
                  Text(
                    '"${request.message}"',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF8E8E93),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundButton(
                icon: CupertinoIcons.xmark,
                color: const Color(0xFFFF3B30),
                onTap: onDecline,
              ),
              const SizedBox(width: 6),
              _RoundButton(
                icon: CupertinoIcons.checkmark,
                color: const Color(0xFF34C759),
                onTap: onAccept,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupInviteCard extends StatelessWidget {
  const _GroupInviteCard({
    required this.invite,
    required this.isFirst,
    required this.isLast,
    required this.onAccept,
    required this.onDecline,
  });
  final GroupInviteInboxItem invite;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: _radius,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.person_2_fill,
              size: 18,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.groupName,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Manrope',
                  ),
                ),
                Text(
                  'Invited by ${invite.inviterName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundButton(
                icon: CupertinoIcons.xmark,
                color: const Color(0xFFFF3B30),
                onTap: onDecline,
              ),
              const SizedBox(width: 6),
              _RoundButton(
                icon: CupertinoIcons.checkmark,
                color: const Color(0xFF34C759),
                onTap: onAccept,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    required this.onUnfriend,
  });

  final FriendUser friend;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
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
        color: AppColors.surface,
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
                Stack(
                  children: [
                    PersonAvatar(name: friend.displayName, radius: 20),
                    if (friend.isAvailable)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF34C759),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
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
                          color: AppColors.textPrimary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      Text(
                        PhonePrivacy.mask(
                          friend.phoneNumber,
                          hide: friend.hidePhoneNumber,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Color(0xFFC7C7CC),
                ),
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
        color: AppColors.surface,
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.person_2_fill,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontFamily: 'Manrope',
                              ),
                            ),
                          ),
                          if (group.isOwner)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  'Owner',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Color(0xFFC7C7CC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small utility widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF3C3C43),
          ),
        ),
      ),
    );
  }
}

class _CtaBanner extends StatelessWidget {
  const _CtaBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });
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
        decoration: const BoxDecoration(
          color: Color(0xFFE5E5EA),
          shape: BoxShape.circle,
        ),
        child:
            loading
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
// iOS-style form widgets
// ─────────────────────────────────────────────────────────────────────────────

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
          prefixIcon: const Icon(
            CupertinoIcons.search,
            size: 16,
            color: Color(0xFF8E8E93),
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

class _IosTextField extends StatelessWidget {
  const _IosTextField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.autofocus = false,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        autofocus: autofocus,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
        style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
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
    this.icon,
  });
  final String label;
  final VoidCallback? onTap;
  final bool secondary;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fgColor = secondary ? const Color(0xFF000000) : Colors.white;
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: secondary ? AppColors.background : AppColors.accent,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child:
              loading
                  ? CupertinoActivityIndicator(
                    color: secondary ? AppColors.accent : Colors.white,
                  )
                  : icon != null
                  ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: fgColor),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: fgColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
                  )
                  : Text(
                    label,
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Manrope',
                    ),
                  ),
        ),
      ),
    );
  }
}

class _BottomSheetCard extends StatelessWidget {
  const _BottomSheetCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 16,
            color: Color(0xFFFF3B30),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13.5),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onDismiss,
            child: const Icon(
              CupertinoIcons.xmark,
              size: 14,
              color: Color(0xFFFF3B30),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented Control
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.selected,
    required this.onChanged,
    required this.labels,
    required this.badges,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  final List<int> badges;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardDivider, width: 0.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                left: selected * segW,
                top: 0,
                bottom: 0,
                width: segW,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  labels.length,
                  (i) => Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    i == selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                color:
                                    i == selected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                fontFamily: 'Manrope',
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (badges[i] > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF3B30),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${badges[i]}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

SliverToBoxAdapter _sectionHeader(String text) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.3,
        ),
      ),
    ),
  );
}

BorderRadius _cardBorderRadius(int i, int total) {
  const r = Radius.circular(14);
  if (total == 1) return const BorderRadius.all(r);
  if (i == 0) return const BorderRadius.only(topLeft: r, topRight: r);
  if (i == total - 1) {
    return const BorderRadius.only(bottomLeft: r, bottomRight: r);
  }
  return BorderRadius.zero;
}
