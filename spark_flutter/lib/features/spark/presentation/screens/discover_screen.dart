import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/notifications/presentation/screens/notification_screen.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../domain/spark.dart';
import '../../domain/spark_invite.dart';
import '../controllers/spark_controller.dart';
import 'spark_detail_screen.dart';
import 'activity_screen.dart';
import '../widgets/location_picker_sheet.dart';

const _kHeroActionBlue = Color(0xFF355588);
const _kHeroActionBlueDeep = Color(0xFF294975);

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const int _pageSize = 10;
  SparkCategory? selectedCategory;
  int radius = 5;
  String query = '';
  late final ScrollController _scrollController;
  bool _isInfiniteScrolling = false;
  String _timingTab = 'all';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      final session = ref.read(authSessionProvider);
      final guestShowcase =
          ref.read(guestShowcaseModeProvider) ||
          (session?.isGuestShowcase ?? false);
      if (!guestShowcase) {
        ref
            .read(sparkDataControllerProvider)
            .refreshNearby(radiusKm: radius.toDouble());
        ref.read(sparkDataControllerProvider).refreshInvites();
      }
    });
  }

  void _onScroll() {
    if (_isInfiniteScrolling) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      final hasMore = ref.read(nearbyHasMoreProvider);
      final loadingMore = ref.read(sparksLoadingMoreProvider);
      if (hasMore && !loadingMore) {
        setState(() => _isInfiniteScrolling = true);
        ref
            .read(sparkDataControllerProvider)
            .fetchNextNearbyPage(radiusKm: radius.toDouble())
            .whenComplete(() {
              if (mounted) setState(() => _isInfiniteScrolling = false);
            });
      }
    }
  }

  Future<void> _onRefresh() async {
    final session = ref.read(authSessionProvider);
    final guestShowcase =
        ref.read(guestShowcaseModeProvider) ||
        (session?.isGuestShowcase ?? false);
    if (guestShowcase) return;
    await Future.wait([
      ref
          .read(sparkDataControllerProvider)
          .refreshNearby(radiusKm: radius.toDouble()),
      ref.read(sparkDataControllerProvider).refreshInvites(),
    ]);
  }

  void _openProfile(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<Spark> _applyFilters(List<Spark> sparks) {
    return sparks
        .where(
          (spark) =>
              (selectedCategory == null ||
                  spark.category == selectedCategory) &&
              spark.distanceKm <= radius &&
              (query.isEmpty ||
                  spark.title.toLowerCase().contains(query) ||
                  spark.location.toLowerCase().contains(query) ||
                  spark.category.label.toLowerCase().contains(query)) &&
              (_timingTab == 'all' ||
                  (_timingTab == 'now' && spark.startsInMinutes <= 30) ||
                  (_timingTab == 'soon' && spark.startsInMinutes <= 120) ||
                  (_timingTab == 'tonight' && spark.startsInMinutes <= 480)),
        )
        .toList();
  }

  Spark _guestShowcaseSpark() {
    return Spark(
      id: 'guest-preview-spark-1',
      category: SparkCategory.sports,
      title: 'Cricket match at central park',
      startsInMinutes: 20,
      timeLabel: 'In 20m',
      distanceKm: 0.2,
      distanceLabel: '200m away',
      spotsLeft: 2,
      maxSpots: 8,
      location: 'Central Park',
      createdBy: 'host-preview',
      participants: const ['RK', 'SN', 'AB'],
      hostPhoneNumber: null,
      note: 'Preview event',
      visibility: SparkVisibility.publicSpark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sparks = ref.watch(sparksProvider);
    final session = ref.watch(authSessionProvider);
    final isGuestShowcase =
        ref.watch(guestShowcaseModeProvider) ||
        (session?.isGuestShowcase ?? false);
    final currentUserId = ref.watch(currentUserIdProvider);
    final displayName = ref.watch(authSessionProvider)?.displayName ?? 'Spark';
    final selectedLocation = ref.watch(selectedLocationProvider);
    final loading = ref.watch(sparksLoadingProvider);
    final loadingMore = ref.watch(sparksLoadingMoreProvider);
    final loadError = ref.watch(sparksErrorProvider);
    final joinedSparkIds = ref.watch(joinedSparkIdsProvider);
    final joinedSparks = ref.watch(joinedSparksProvider);
    final createdSparks = ref.watch(myCreatedSparksProvider);
    final pendingInvites =
        ref
            .watch(sparkInvitesProvider)
            .where((invite) => invite.status == SparkInviteStatus.pending)
            .length;
    final showMyActivity = joinedSparks.isNotEmpty || createdSparks.isNotEmpty;
    final discoverableSparks =
        isGuestShowcase
            ? [_guestShowcaseSpark()]
            : sparks.where((spark) {
              final isJoined = joinedSparkIds.contains(spark.id);
              return !isJoined;
            }).toList();
    final filtered =
        isGuestShowcase
            ? discoverableSparks
            : _applyFilters(discoverableSparks);
    final effectiveLoadError = isGuestShowcase ? null : loadError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.paddingOf(context).top,
              color: const Color(0xFF003366),
            ),
          ),
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.accent,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Pinned header: expands at top, collapses on scroll ─
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DiscoverHeaderDelegate(
                    topPadding: MediaQuery.paddingOf(context).top,
                    displayName: displayName,
                    selectedLocation: selectedLocation,
                    radius: radius,
                    onLocationTap: () => _showLocationSelector(context),
                    onRadiusTap: () => _showPreferencesSheet(context),
                    onNotificationTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationScreen(),
                          ),
                        ),
                    onProfileTap: () => _openProfile(context),
                    searchQuery: query,
                    onSearchChanged:
                        (v) => setState(() => query = v.trim().toLowerCase()),
                    onSearchSubmitted:
                        (v) => setState(() => query = v.trim().toLowerCase()),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Category chips ────────────────────────────
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _CategoryChip(
                                label: 'All',
                                icon: Icons.apps_outlined,
                                selected: selectedCategory == null,
                                count: discoverableSparks.length,
                                onTap:
                                    () => setState(() {
                                      selectedCategory = null;
                                    }),
                              ),
                              ...SparkCategory.values
                                  .where((c) => c != SparkCategory.hangout)
                                  .map(
                                    (category) => _CategoryChip(
                                      label: category.label,
                                      icon: category.icon,
                                      selected: selectedCategory == category,
                                      count:
                                          discoverableSparks
                                              .where(
                                                (s) => s.category == category,
                                              )
                                              .length,
                                      onTap:
                                          () => setState(() {
                                            selectedCategory = category;
                                          }),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // const _AiRadarPanel(),
                        // const SizedBox(height: 20),
                        // ── Section header ────────────────────────────
                        Row(
                          children: [
                            const _LiveHeader(),
                            const Spacer(),
                            if (showMyActivity) ...[
                              GestureDetector(
                                onTap:
                                    () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const ActivityScreen(),
                                      ),
                                    ),
                                child: const Text(
                                  'Activity',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (pendingInvites > 0)
                              GestureDetector(
                                onTap: () {
                                  ref.read(bottomTabProvider.notifier).state =
                                      2;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Invites ($pendingInvites)',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showPreferencesSheet(context),
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ── Sort toggle (hidden in map view) ──────────
                        if (!isGuestShowcase)
                          _SortToggle(
                            selected: ref.watch(selectedSortProvider),
                            onSelect:
                                (s) =>
                                    ref
                                        .read(selectedSortProvider.notifier)
                                        .state = s,
                          ),
                        if (isGuestShowcase)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentSurface.withValues(
                                alpha: 0.28,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                  color: AppColors.accent,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Guest preview mode. Login to see what is happening around you.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        if (loading && !isGuestShowcase)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (effectiveLoadError != null &&
                            effectiveLoadError.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.errorSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.errorText),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 16,
                                  color: AppColors.errorText,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Could not refresh sparks. Pull down to retry.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.errorText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (filtered.isEmpty && !loading) const _EmptyState(),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child:
                        filtered.isEmpty
                            ? const SizedBox.shrink()
                            : Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.cardShadow,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < filtered.length;
                                      i++
                                    ) ...[
                                      if (i > 0)
                                        const Divider(
                                          height: 1,
                                          thickness: 1,
                                          indent: 54,
                                          endIndent: 16,
                                          color: AppColors.cardDivider,
                                        ),
                                      _NearbyCard(
                                        spark: filtered[i],
                                        isHostedByYou:
                                            filtered[i].createdBy ==
                                            currentUserId,
                                        ctaLabel:
                                            isGuestShowcase
                                                ? 'Preview'
                                                : joinedSparkIds.contains(
                                                  filtered[i].id,
                                                )
                                                ? 'Chat'
                                                : 'Join',
                                        onTap: () {
                                          if (isGuestShowcase) return;
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => SparkDetailScreen(
                                                    spark: filtered[i],
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    20 + MediaQuery.paddingOf(context).bottom + 76,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (loadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        if (filtered.isNotEmpty && !loadingMore)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                              'You\'re all caught up nearby.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        const _CreateNudge(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationSelector(BuildContext context) {
    final saved = ref.read(savedLocationsProvider);
    final recent = ref.read(recentLocationsProvider);
    final catalog = ref.read(locationCatalogProvider);
    final selected = ref.read(selectedLocationProvider);
    final placesService = ref.read(placesAutocompleteServiceProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => LocationPickerSheet(
            title: 'Choose location',
            selectedLocation: selected,
            savedLocations: saved,
            recentLocations: recent,
            catalogLocations: catalog,
            placesService: placesService,
            onSelect: (place) {
              ref.read(selectedLocationProvider.notifier).state = place;
              ref
                  .read(sparkDataControllerProvider)
                  .refreshNearby(radiusKm: radius.toDouble());
              Navigator.of(context).pop();
            },
          ),
    );
  }

  void _showPreferencesSheet(BuildContext context) {
    var draftRadius = radius;
    var draftCategory = selectedCategory;
    var draftTiming = _timingTab;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setSheetState) => SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Search Preferences',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Manrope',
                            letterSpacing: -0.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Customize your discovery feed',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                            fontFamily: 'Manrope',
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Discovery Radius',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$draftRadius km',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 9,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 18,
                            ),
                            activeTrackColor: AppColors.accent,
                            inactiveTrackColor: AppColors.accent.withValues(
                              alpha: 0.1,
                            ),
                            thumbColor: AppColors.accent,
                          ),
                          child: Slider(
                            value: draftRadius.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            onChanged: (value) {
                              setSheetState(() => draftRadius = value.round());
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Activity Type',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _SelectionChip(
                              label: 'Any',
                              selected: draftCategory == null,
                              onTap:
                                  () =>
                                      setSheetState(() => draftCategory = null),
                            ),
                            ...SparkCategory.values
                                .where((c) => c != SparkCategory.hangout)
                                .map(
                                  (category) => _SelectionChip(
                                    label: category.label,
                                    selected: draftCategory == category,
                                    onTap:
                                        () => setSheetState(
                                          () => draftCategory = category,
                                        ),
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Timing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _SelectionChip(
                              label: 'All',
                              selected: draftTiming == 'all',
                              onTap:
                                  () =>
                                      setSheetState(() => draftTiming = 'all'),
                            ),
                            _SelectionChip(
                              label: 'Now',
                              selected: draftTiming == 'now',
                              onTap:
                                  () =>
                                      setSheetState(() => draftTiming = 'now'),
                            ),
                            _SelectionChip(
                              label: 'Soon',
                              selected: draftTiming == 'soon',
                              onTap:
                                  () =>
                                      setSheetState(() => draftTiming = 'soon'),
                            ),
                            _SelectionChip(
                              label: 'Tonight',
                              selected: draftTiming == 'tonight',
                              onTap:
                                  () => setSheetState(
                                    () => draftTiming = 'tonight',
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _kHeroActionBlueDeep.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _kHeroActionBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  radius = draftRadius;
                                  selectedCategory = draftCategory;
                                  _timingTab = draftTiming;
                                });
                                ref
                                    .read(sparkDataControllerProvider)
                                    .refreshNearby(
                                      radiusKm: draftRadius.toDouble(),
                                    );
                                Navigator.of(context).pop();
                              },
                              child: const Text('Apply Preferences'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}

// ── Heights must match the measured content inside each state ──────────────
const double _kExpandedHeightBase = 276.0;
const double _kCollapsedHeightBase = 124.0;

class _DiscoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DiscoverHeaderDelegate({
    required this.topPadding,
    required this.displayName,
    required this.selectedLocation,
    required this.radius,
    required this.onLocationTap,
    required this.onRadiusTap,
    required this.onNotificationTap,
    required this.onProfileTap,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final double topPadding;
  final String displayName;
  final String selectedLocation;
  final int radius;
  final VoidCallback onLocationTap;
  final VoidCallback onRadiusTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  double get minExtent => _kCollapsedHeightBase + topPadding;

  @override
  double get maxExtent => _kExpandedHeightBase + topPadding;

  @override
  bool shouldRebuild(_DiscoverHeaderDelegate old) =>
      old.displayName != displayName ||
      old.selectedLocation != selectedLocation ||
      old.radius != radius ||
      old.searchQuery != searchQuery;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final collapsed = t > 0.4;

    // ClipRect + fixed SizedBox ensures the Column never overflows the
    // pinned header as shrinkOffset reduces the available height.
    return ClipRect(
      child: SizedBox(
        height: maxExtent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder:
              (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
          child:
              collapsed
                  ? _HeroCollapsed(
                    key: const ValueKey('c'),
                    displayName: displayName,
                    selectedLocation: selectedLocation,
                    onNotificationTap: onNotificationTap,
                    onProfileTap: onProfileTap,
                    searchQuery: searchQuery,
                    onSearchChanged: onSearchChanged,
                    onSearchSubmitted: onSearchSubmitted,
                  )
                  : _HeroPanel(
                    key: const ValueKey('e'),
                    selectedLocation: selectedLocation,
                    radius: radius,
                    onLocationTap: onLocationTap,
                    onRadiusTap: onRadiusTap,
                    onNotificationTap: onNotificationTap,
                    onProfileTap: onProfileTap,
                    searchQuery: searchQuery,
                    onSearchChanged: onSearchChanged,
                    onSearchSubmitted: onSearchSubmitted,
                  ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatefulWidget {
  const _HeroPanel({
    super.key,
    required this.selectedLocation,
    required this.radius,
    required this.onLocationTap,
    required this.onRadiusTap,
    required this.onNotificationTap,
    required this.onProfileTap,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String selectedLocation;
  final int radius;
  final VoidCallback onLocationTap;
  final VoidCallback onRadiusTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  State<_HeroPanel> createState() => _HeroPanelState();
}

class _HeroPanelState extends State<_HeroPanel> with TickerProviderStateMixin {
  late final AnimationController _floatCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _floatCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  String _compactLocation(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return 'Near you';
    if (cleaned.length <= 22) return cleaned;
    return '${cleaned.substring(0, 22)}…';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: AnimatedBuilder(
        animation: _floatCtrl,
        builder: (context, child) {
          final floatT = _floatCtrl.value;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.7, 1.0],
                colors: [
                  Color(0xFF003366),
                  Color(0xFF002244),
                  Color(0xFF001122),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Deep Purple Glow - Top Left
                Positioned(
                  left: -80 + floatT * 15,
                  top: -80 - floatT * 10,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFF4F46E5,
                          ).withValues(alpha: 0.12 + floatT * 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Soft Indigo Glow - Bottom Right
                Positioned(
                  right: -100 - floatT * 20,
                  bottom: -100 + floatT * 15,
                  child: Container(
                    width: 350,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.1 + floatT * 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Magical "Sparkle" Orbs
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left:
                        40.0 + (i * 100) + (floatT * 20 * (i.isEven ? 1 : -1)),
                    top: 60.0 + (i * 40) - (floatT * 15 * (i.isOdd ? 1 : -1)),
                    child: Container(
                      width: 2 + (i.toDouble()),
                      height: 2 + (i.toDouble()),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: 0.4 + floatT * 0.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 4 + i.toDouble(),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                child!,
              ],
            ),
          );
        },
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                13 + MediaQuery.paddingOf(context).top,
                22,
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: location, radius, actions ───────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: widget.onLocationTap,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      9,
                                      6,
                                      9,
                                      6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF86EFAC),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            _compactLocation(
                                              widget.selectedLocation,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 14,
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: widget.onRadiusTap,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${widget.radius}km',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.tune_rounded,
                                        size: 12,
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: widget.onNotificationTap,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.notifications_outlined,
                          size: 21,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onProfileTap,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 17,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // ── Headline ──────────────────────────────────────────────
                  ShaderMask(
                    shaderCallback:
                        (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFA5B4FC)],
                        ).createShader(bounds),
                    child: const Text(
                      'Explore what\'s\nhappening near you.',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Manrope',
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Real people. Real plans. Right now.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontFamily: 'Manrope',
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _HeroBannerSearch(
                    currentQuery: widget.searchQuery,
                    onQueryChanged: (v) {
                      widget.onSearchChanged(v);
                      widget.onSearchSubmitted(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual-only search bar. Tapping pushes [_SearchScreen] — a Swiggy-style
/// full-screen search page where the TextField lives in a normal Scaffold.
class _HeroBannerSearch extends StatelessWidget {
  const _HeroBannerSearch({
    required this.currentQuery,
    required this.onQueryChanged,
  });

  final String currentQuery;
  final ValueChanged<String> onQueryChanged;

  Future<void> _openSearch(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => _SearchScreen(initialQuery: currentQuery),
        transitionsBuilder:
            (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
    if (result != null) onQueryChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = currentQuery.isNotEmpty;
    return GestureDetector(
      onTap: () => _openSearch(context),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.search,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasQuery ? currentQuery : 'Search activities, sports, study...',
                style: TextStyle(
                  fontSize: 15,
                  color:
                      hasQuery
                          ? AppColors.textPrimary
                          : AppColors.textSecondary.withValues(alpha: 0.7),
                  fontFamily: 'Manrope',
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen search page — Swiggy-style ─────────────────────────────────
class _SearchScreen extends StatefulWidget {
  const _SearchScreen({required this.initialQuery});
  final String initialQuery;

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialQuery,
  );
  String _query = '';

  static const _recentTags = [
    'Cricket',
    'Coffee',
    'Study',
    'Cycling',
    'Drive',
    'Badminton',
  ];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    Navigator.of(context).pop(q.toLowerCase());
  }

  void _closeWithCurrentQuery() {
    Navigator.of(context).pop(_query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _closeWithCurrentQuery();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar: back + search field ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    // back arrow
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        color: AppColors.onSurfaceEmphasis,
                      ),
                      onPressed: _closeWithCurrentQuery,
                    ),
                    // search field
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        contextMenuBuilder: null,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setState(() => _query = v.trim()),
                        onSubmitted: _submit,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.chipBg,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppColors.accent,
                          ),
                          suffixIcon:
                              _query.isNotEmpty
                                  ? GestureDetector(
                                    onTap: () {
                                      _ctrl.clear();
                                      setState(() => _query = '');
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                  : null,
                          hintText: 'Search plans, sports, study, ride…',
                          hintStyle: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.chipBorder,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.chipBorder,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Recently searched ─────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'RECENTLY SEARCHED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _recentTags.map((tag) {
                        final isActive =
                            _query.toLowerCase() == tag.toLowerCase();
                        return GestureDetector(
                          onTap: () => _submit(tag),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isActive
                                      ? _kHeroActionBlue
                                      : AppColors.chipSelectedBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    isActive
                                        ? _kHeroActionBlueDeep
                                        : AppColors.chipBorder,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 13,
                                  color:
                                      isActive
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isActive
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCollapsed extends StatelessWidget {
  const _HeroCollapsed({
    super.key,
    required this.displayName,
    required this.selectedLocation,
    required this.onNotificationTap,
    required this.onProfileTap,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String displayName;
  final String selectedLocation;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroBg2, AppColors.heroBg4],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8 + MediaQuery.paddingOf(context).top,
        16,
        8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Manrope',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '•',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Icon(
                Icons.location_on_rounded,
                size: 11,
                color: AppColors.orbGreen.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 3),
              Text(
                selectedLocation,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onNotificationTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.notifications_outlined,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _HeroBannerSearch(
            currentQuery: searchQuery,
            onQueryChanged: (v) {
              onSearchChanged(v);
              onSearchSubmitted(v);
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.selected, required this.onSelect});

  final SparkSort selected;
  final ValueChanged<SparkSort> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.pillSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children:
            SparkSort.values.map((sort) {
              final isSelected = sort == selected;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(sort),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      sort.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isSelected
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                        fontFamily: 'Manrope',
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final isEmpty = count != null && count! == 0;

    const activeBg = _kHeroActionBlue;
    const activeText = Colors.white;
    const iconColor = Colors.white;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: isEmpty ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: BoxDecoration(
            color:
                selected
                    ? null
                    : isEmpty
                    ? AppColors.pillSurface.withValues(alpha: 0.5)
                    : Colors.white,
            gradient:
                selected
                    ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_kHeroActionBlue, _kHeroActionBlueDeep],
                    )
                    : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected
                      ? _kHeroActionBlueDeep
                      : isEmpty
                      ? AppColors.border.withValues(alpha: 0.3)
                      : AppColors.border.withValues(alpha: 0.8),
              width: 1,
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: _kHeroActionBlueDeep.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
              ],
              Text(
                count != null ? '$label ($count)' : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color:
                      selected
                          ? activeText
                          : isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                  fontFamily: 'Manrope',
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.chipAccentBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.explore_off_outlined,
              size: 30,
              color: AppColors.chipAccentText,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No sparks nearby yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try widening your radius or\nchecking back in a bit.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(bottomTabProvider.notifier).state = 1,
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Be the first — create one'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kHeroActionBlue,
              side: const BorderSide(color: _kHeroActionBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyCard extends StatefulWidget {
  const _NearbyCard({
    required this.spark,
    required this.isHostedByYou,
    required this.onTap,
    required this.ctaLabel,
  });

  final Spark spark;
  final bool isHostedByYou;
  final VoidCallback onTap;
  final String ctaLabel;

  @override
  State<_NearbyCard> createState() => _NearbyCardState();
}

class _NearbyCardState extends State<_NearbyCard> {
  Timer? _timer;

  static const _avatarInitials = ['A', 'J', 'S', 'M', 'R', 'K', 'P', 'D'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static IconData _categoryIcon(SparkCategory cat) => switch (cat) {
    SparkCategory.sports => CupertinoIcons.sportscourt,
    SparkCategory.study => CupertinoIcons.book,
    SparkCategory.ride => CupertinoIcons.car,
    SparkCategory.events => CupertinoIcons.ticket,
    SparkCategory.hangout => CupertinoIcons.person_3,
  };

  static Color _catColor(SparkCategory cat) => cat.accentColor;

  // ignore: unused_element
  static Color _catBg(SparkCategory cat) =>
      cat.accentColor.withValues(alpha: 0.08);

  String _countdown() {
    final mins = widget.spark.startsInMinutes;
    if (mins <= 0) return 'Starting now';
    if (mins < 60) return 'In ${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? 'In ${h}h' : 'In ${h}h ${m}m';
  }

  List<(Color, String)> _avatars() {
    final seed = widget.spark.id.hashCode.abs();
    final count = 2 + (seed % 2);
    return List.generate(count, (i) {
      final ii = (seed + i * 13) % _avatarInitials.length;
      return (AppColors.avatarBg, _avatarInitials[ii]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spark = widget.spark;
    final icon = _categoryIcon(spark.category);
    final isHappeningNow = spark.startsInMinutes <= 15;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _catBg(spark.category),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: _catColor(spark.category)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spark.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontFamily: 'Manrope',
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (widget.isHostedByYou)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Hosted by you',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  if (spark.isRecurring)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 11,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            spark.recurrenceType == 'DAILY'
                                ? 'Repeats daily'
                                : 'Repeats weekly',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.time_solid,
                        size: 13,
                        color:
                            isHappeningNow
                                ? AppColors.action.withValues(alpha: 0.8)
                                : AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _countdown(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isHappeningNow
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                          color:
                              isHappeningNow
                                  ? AppColors.action
                                  : AppColors.textSecondary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        CupertinoIcons.location_solid,
                        size: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        spark.distanceLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _AvatarStack(
                        avatars: _avatars(),
                        total: spark.participants.length,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${spark.participants.length} joining',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                      if (spark.spotsLeft <= 2) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· ${spark.spotsLeft} spots',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.errorText,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars, required this.total});
  final List<(Color, String)> avatars;
  final int total;

  static const int _maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    const overlap = 11.0;
    final shown = avatars.length.clamp(0, _maxVisible);
    final overflow = total > shown ? total - shown : 0;
    final slots = shown + (overflow > 0 ? 1 : 0);
    final totalWidth = slots <= 1 ? size : size + (slots - 1) * overlap;

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: avatars[i].$1,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  avatars[i].$2,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: shown * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveHeader extends StatefulWidget {
  const _LiveHeader();

  @override
  State<_LiveHeader> createState() => _LiveHeaderState();
}

class _LiveHeaderState extends State<_LiveHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Happening nearby',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            fontFamily: 'Manrope',
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(
                      alpha: 0.4 * _pulse.value,
                    ),
                    blurRadius: 6 + _pulse.value * 4,
                    spreadRadius: _pulse.value * 2,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CreateNudge extends ConsumerWidget {
  const _CreateNudge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 22, color: _kHeroActionBlue),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Nothing nearby? Start one.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kHeroActionBlue,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a plan. Someone nearby might join.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              ref.read(bottomTabProvider.notifier).state = 1;
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kHeroActionBlue, _kHeroActionBlueDeep],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _kHeroActionBlueDeep.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 7),
                  Text(
                    'Create a spark',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map/List toggle button ───────────────────────────────────────────────────

class _MapListToggle extends StatelessWidget {
  const _MapListToggle({required this.isMap, required this.onToggle});
  final bool isMap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMap ? _kHeroActionBlue : AppColors.surfaceSubtle,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isMap ? Icons.list_rounded : Icons.map_outlined,
          size: 15,
          color: isMap ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? null : AppColors.chipBg,
          gradient:
              selected
                  ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kHeroActionBlue, _kHeroActionBlueDeep],
                  )
                  : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kHeroActionBlueDeep : AppColors.chipBorder,
            width: 1,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: _kHeroActionBlueDeep.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
            fontFamily: 'Manrope',
          ),
        ),
      ),
    );
  }
}
