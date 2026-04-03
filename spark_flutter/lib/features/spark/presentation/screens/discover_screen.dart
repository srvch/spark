import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../domain/spark.dart';
import '../../domain/spark_invite.dart';
import '../controllers/spark_controller.dart';
import 'spark_detail_screen.dart';
import 'activity_screen.dart';
import '../widgets/location_picker_sheet.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const int _pageSize = 10;
  SparkCategory? selectedCategory = SparkCategory.sports;
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
      ref
          .read(sparkDataControllerProvider)
          .refreshNearby(radiusKm: radius.toDouble());
      ref.read(sparkDataControllerProvider).refreshInvites();
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

  @override
  Widget build(BuildContext context) {
    final sparks = ref.watch(sparksProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final selectedLocation = ref.watch(selectedLocationProvider);
    final loading = ref.watch(sparksLoadingProvider);
    final loadingMore = ref.watch(sparksLoadingMoreProvider);
    final loadError = ref.watch(sparksErrorProvider);
    final joinedSparkIds = ref.watch(joinedSparkIdsProvider);
    final joinedSparks = ref.watch(joinedSparksProvider);
    final createdSparks = ref.watch(myCreatedSparksProvider);
    final pendingInvites = ref
        .watch(sparkInvitesProvider)
        .where((invite) => invite.status == SparkInviteStatus.pending)
        .length;
    final showMyActivity = joinedSparks.isNotEmpty || createdSparks.isNotEmpty;
    final createdSparkIds = createdSparks.map((spark) => spark.id).toSet();
    final discoverableSparks = sparks.where((spark) {
      final isMineById = createdSparkIds.contains(spark.id);
      final isMineByHost = spark.createdBy == currentUserId;
      final isJoined = joinedSparkIds.contains(spark.id);
      return !isMineById && !isMineByHost && !isJoined;
    }).toList();
    final filtered = _applyFilters(discoverableSparks);
    final isMapView = ref.watch(discoverMapViewProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
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
                  selectedLocation: selectedLocation,
                  radius: radius,
                  onLocationTap: () => _showLocationSelector(context),
                  onRadiusTap: () => _showPreferencesSheet(context),
                  onProfileTap: () => _openProfile(context),
                  searchQuery: query,
                  onSearchChanged: (v) =>
                      setState(() => query = v.trim().toLowerCase()),
                  onSearchSubmitted: (v) =>
                      setState(() => query = v.trim().toLowerCase()),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                              onTap: () => setState(() {
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
                                    count: discoverableSparks
                                        .where((s) => s.category == category)
                                        .length,
                                    onTap: () => setState(() {
                                      selectedCategory = category;
                                    }),
                                  ),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Section header ────────────────────────────
                      Row(
                        children: [
                          const _LiveHeader(),
                          const Spacer(),
                          if (showMyActivity) ...[
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
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
                                ref.read(bottomTabProvider.notifier).state = 2;
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
                          const SizedBox(width: 6),
                          _MapListToggle(
                            isMap: ref.watch(discoverMapViewProvider),
                            onToggle: () {
                              HapticFeedback.selectionClick();
                              ref.read(discoverMapViewProvider.notifier).state =
                                  !ref.read(discoverMapViewProvider);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // ── Sort toggle (hidden in map view) ──────────
                      if (!ref.watch(discoverMapViewProvider))
                      _SortToggle(
                        selected: ref.watch(selectedSortProvider),
                        onSelect: (s) =>
                            ref.read(selectedSortProvider.notifier).state = s,
                      ),
                      const SizedBox(height: 10),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (loadError != null && loadError.isNotEmpty)
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
                                    color: AppColors.accent,
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
              if (isMapView)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _DiscoverMapView(
                    sparks: filtered,
                    onSparkTap: (spark) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SparkDetailScreen(spark: spark),
                      ),
                    ),
                  ),
                )
              else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: filtered.isEmpty
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
                                for (var i = 0; i < filtered.length; i++) ...[
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
                                    ctaLabel:
                                        joinedSparkIds.contains(filtered[i].id)
                                        ? 'Chat'
                                        : 'Join',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => SparkDetailScreen(
                                          spark: filtered[i],
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
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
      builder: (_) => LocationPickerSheet(
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
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferences',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Distance',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '$draftRadius km',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Slider(
                  value: draftRadius.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) {
                    setSheetState(() => draftRadius = value.round());
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Spark type',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: draftCategory == null,
                      onSelected: (_) =>
                          setSheetState(() => draftCategory = null),
                    ),
                    ...SparkCategory.values
                        .where((c) => c != SparkCategory.hangout)
                        .map(
                          (category) => ChoiceChip(
                            label: Text(category.label),
                            selected: draftCategory == category,
                            onSelected: (_) =>
                                setSheetState(() => draftCategory = category),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Timing',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: draftTiming == 'all',
                      onSelected: (_) =>
                          setSheetState(() => draftTiming = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('Now (≤30 min)'),
                      selected: draftTiming == 'now',
                      onSelected: (_) =>
                          setSheetState(() => draftTiming = 'now'),
                    ),
                    ChoiceChip(
                      label: const Text('Soon (≤2 hrs)'),
                      selected: draftTiming == 'soon',
                      onSelected: (_) =>
                          setSheetState(() => draftTiming = 'soon'),
                    ),
                    ChoiceChip(
                      label: const Text('Tonight'),
                      selected: draftTiming == 'tonight',
                      onSelected: (_) =>
                          setSheetState(() => draftTiming = 'tonight'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                        .refreshNearby(radiusKm: draftRadius.toDouble());
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'APPLY',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
const double _kExpandedHeight = 258.0;
const double _kCollapsedHeight = 96.0;

class _DiscoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DiscoverHeaderDelegate({
    required this.selectedLocation,
    required this.radius,
    required this.onLocationTap,
    required this.onRadiusTap,
    required this.onProfileTap,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String selectedLocation;
  final int radius;
  final VoidCallback onLocationTap;
  final VoidCallback onRadiusTap;
  final VoidCallback onProfileTap;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  double get minExtent => _kCollapsedHeight;

  @override
  double get maxExtent => _kExpandedHeight;

  @override
  bool shouldRebuild(_DiscoverHeaderDelegate old) =>
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
    final collapsed = t > 0.55;

    // ClipRect + fixed SizedBox ensures the Column never overflows the
    // pinned header as shrinkOffset reduces the available height.
    return ClipRect(
      child: SizedBox(
        height: maxExtent,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: collapsed
              ? _HeroCollapsed(
                  key: const ValueKey('c'),
                  selectedLocation: selectedLocation,
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
    required this.onProfileTap,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String selectedLocation;
  final int radius;
  final VoidCallback onLocationTap;
  final VoidCallback onRadiusTap;
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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: AnimatedBuilder(
        animation: _floatCtrl,
        builder: (context, child) {
          final floatT = _floatCtrl.value;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A1628),
                  Color(0xFF0F1F3D),
                  Color(0xFF152B50),
                  Color(0xFF1C3360),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Aurora: large blue glow, top-right
                Positioned(
                  right: -60 + floatT * 12,
                  top: -60 + floatT * 8,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF3B82F6).withValues(alpha: 0.17 + floatT * 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Aurora: soft green tint, bottom-left
                Positioned(
                  left: -50 + floatT * 10,
                  bottom: -50 + floatT * 8,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF86EFAC).withValues(alpha: 0.09 + floatT * 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Subtle vignette bottom
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                // Floating live activity widget (upper right)
                Positioned(
                  right: 18,
                  top: 42 + floatT * 5,
                  child: _LiveNearbyBadge(floatT: floatT),
                ),
                // Micro sparkle dots
                Positioned(
                  right: 88 + floatT * 3,
                  top: 26 - floatT * 4,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22 + floatT * 0.12),
                    ),
                  ),
                ),
                Positioned(
                  right: 148 - floatT * 4,
                  bottom: 56 + floatT * 5,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF86EFAC).withValues(alpha: 0.28 + floatT * 0.14),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 13, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting row ──────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _greeting,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.52),
                        fontFamily: 'Manrope',
                        letterSpacing: 0.1,
                      ),
                    ),
                    const Spacer(),
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
                const SizedBox(height: 7),
                // ── Location pill ─────────────────────────────────────────
                GestureDetector(
                  onTap: widget.onLocationTap,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(9, 4, 9, 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF86EFAC),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.selectedLocation,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '·',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.28),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.radius}km',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.38),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Headline ──────────────────────────────────────────────
                const Text(
                  'Plans happening\nnear you, right now.',
                  style: TextStyle(
                    fontSize: 27,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Manrope',
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Tiny plans. Real people. Right this minute.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 0.05,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                // ── Search bar ────────────────────────────────────────────
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
    );
  }
}

/// Floating glass card showing live nearby activity — replaces the old
/// graphic cluster with a cleaner, more information-dense widget.
class _LiveNearbyBadge extends StatelessWidget {
  const _LiveNearbyBadge({required this.floatT});

  final double floatT;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.09),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF86EFAC),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF86EFAC).withValues(
                        alpha: 0.5 + floatT * 0.2,
                      ),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Live near you',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _MiniSparkRow(
            icon: Icons.sports_cricket_rounded,
            label: 'Cricket match',
            sub: '200m · 5 joining',
          ),
          const SizedBox(height: 7),
          _MiniSparkRow(
            icon: Icons.menu_book_rounded,
            label: 'DSA sprint',
            sub: '450m · 3 joining',
          ),
        ],
      ),
    );
  }
}

class _MiniSparkRow extends StatelessWidget {
  const _MiniSparkRow({
    required this.icon,
    required this.label,
    required this.sub,
  });

  final IconData icon;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.72)),
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                fontSize: 8.5,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ),
          ],
        ),
      ],
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
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
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
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search_rounded,
              size: 16,
              color: Colors.black.withValues(alpha: hasQuery ? 0.55 : 0.28),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasQuery ? currentQuery : 'Search plans, sports, study, ride…',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasQuery ? FontWeight.w600 : FontWeight.w400,
                  color: Colors.black.withValues(alpha: hasQuery ? 0.75 : 0.28),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasQuery)
              GestureDetector(
                onTap: () => onQueryChanged(''),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              )
            else
              const SizedBox(width: 10),
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
    if (q.isNotEmpty) Navigator.of(context).pop(q.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    onPressed: () => Navigator.of(context).pop(null),
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
                        suffixIcon: _query.isNotEmpty
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
                children: _recentTags.map((tag) {
                  final isActive = _query.toLowerCase() == tag.toLowerCase();
                  return GestureDetector(
                    onTap: () => _submit(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.accent
                            : AppColors.chipSelectedBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accent
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
                            color: isActive
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            tag,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isActive
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
    );
  }
}

class _HeroCollapsed extends StatelessWidget {
  const _HeroCollapsed({
    super.key,
    required this.selectedLocation,
    required this.onProfileTap,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String selectedLocation;
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Saurav',
                style: TextStyle(
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
    return Row(
      children: SparkSort.values.map((sort) {
        final isSelected = sort == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(sort),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.pillSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                sort.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: isEmpty ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent
                : isEmpty
                ? AppColors.pillSurface
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : isEmpty
                  ? AppColors.separator
                  : AppColors.separator,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(icon, size: 13, color: Colors.white),
                const SizedBox(width: 5),
              ],
              Text(
                count != null ? '$label ($count)' : label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : isEmpty
                      ? AppColors.textMuted
                      : AppColors.chipText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
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
            onPressed: null,
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Be the first — create one'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
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
    required this.onTap,
    required this.ctaLabel,
  });

  final Spark spark;
  final VoidCallback onTap;
  final String ctaLabel;

  @override
  State<_NearbyCard> createState() => _NearbyCardState();
}

class _NearbyCardState extends State<_NearbyCard> {
  Timer? _timer;

  static const _avatarInitials = ['A', 'J', 'S', 'M', 'R', 'K', 'P', 'D'];

  static const _iconBg = AppColors.iconBg;
  static const _iconFg = AppColors.iconFg;

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
    SparkCategory.sports => Icons.directions_run_rounded,
    SparkCategory.study => Icons.auto_stories_rounded,
    SparkCategory.ride => Icons.drive_eta_rounded,
    SparkCategory.events => Icons.confirmation_number_outlined,
    SparkCategory.hangout => Icons.coffee_outlined,
  };

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
    final isLowSpots = spark.spotsLeft <= 2;
    final isJoined = widget.ctaLabel == 'Chat';
    final avatars = _avatars();
    final isNow = spark.startsInMinutes <= 0;
    final isHappeningNow = spark.startsInMinutes <= 5;

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _iconFg, size: 17),
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
                          spark.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (isHappeningNow) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            isNow ? 'Now' : 'Starting',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: isNow ? AppColors.success : AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _countdown(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: isNow
                              ? AppColors.success
                              : AppColors.textMuted,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '·',
                          style: TextStyle(
                            color: AppColors.separator,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.near_me_rounded,
                        size: 11,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          spark.distanceLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _AvatarStack(
                        avatars: avatars,
                        total: spark.participants.length,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${spark.participants.length} joining',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (isLowSpots) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${spark.spotsLeft} left',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.errorText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isJoined
                    ? AppColors.pillSurface
                    : AppColors.accentSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.ctaLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isJoined ? AppColors.textMuted : AppColors.accent,
                ),
              ),
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
              const Icon(Icons.bolt_rounded, size: 22, color: AppColors.accent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Nothing nearby? Start one.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
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
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(14),
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
          color: isMap ? AppColors.accent : AppColors.surfaceSubtle,
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

// ── Real OpenStreetMap map view ───────────────────────────────────────────────

class _DiscoverMapView extends StatefulWidget {
  const _DiscoverMapView({
    required this.sparks,
    required this.onSparkTap,
  });
  final List<Spark> sparks;
  final void Function(Spark) onSparkTap;

  @override
  State<_DiscoverMapView> createState() => _DiscoverMapViewState();
}

class _DiscoverMapViewState extends State<_DiscoverMapView> {
  Spark? _selectedSpark;

  // Centre the map on Bangalore city
  static const LatLng _bangaloreCenter = LatLng(12.9716, 77.5946);

  // Map well-known Bangalore locations to lat/lng
  static (double lat, double lng) _coordsFor(String location) {
    final l = location.toLowerCase();
    if (l.contains('koramangala')) return (12.9352, 77.6245);
    if (l.contains('indiranagar')) return (12.9784, 77.6408);
    if (l.contains('whitefield'))  return (12.9698, 77.7499);
    if (l.contains('electronic'))  return (12.8456, 77.6603);
    if (l.contains('hsr'))         return (12.9116, 77.6474);
    if (l.contains('bellandur'))   return (12.9259, 77.6762);
    if (l.contains('marathon'))    return (12.9591, 77.6971);
    if (l.contains('jp nagar'))    return (12.9094, 77.5840);
    if (l.contains('jayanagar'))   return (12.9252, 77.5938);
    if (l.contains('church'))      return (12.9756, 77.6055);
    if (l.contains('mg road'))     return (12.9753, 77.6117);
    if (l.contains('brigade'))     return (12.9714, 77.6120);
    if (l.contains('ulsoor'))      return (12.9822, 77.6210);
    if (l.contains('malleshwaram'))return (13.0035, 77.5712);
    if (l.contains('rajajinagar')) return (12.9894, 77.5512);
    if (l.contains('hebbal'))      return (13.0358, 77.5971);
    return (12.9716, 77.5946); // Bangalore city centre fallback
  }

  // Give each spark a small deterministic offset so pins at the same
  // location don't overlap perfectly.
  static LatLng _sparkLatLng(Spark spark) {
    final (lat, lng) = _coordsFor(spark.location);
    final hashA = (spark.id.hashCode * 37).abs() % 1000;
    final hashB = (spark.id.hashCode * 71).abs() % 1000;
    final dLat = (hashA / 1000 - 0.5) * 0.016; // ±0.008°  ≈  ±900 m
    final dLng = (hashB / 1000 - 0.5) * 0.016;
    return LatLng(lat + dLat, lng + dLng);
  }

  // Category → pin colour (delegates to SparkCategory.accentColor)
  static Color _pinColor(SparkCategory category) => category.accentColor;

  @override
  Widget build(BuildContext context) {
    final markers = widget.sparks.map((spark) {
      final pos = _sparkLatLng(spark);
      final color = _pinColor(spark.category);
      final isSelected = _selectedSpark?.id == spark.id;

      return Marker(
        point: pos,
        width: isSelected ? 44 : 36,
        height: isSelected ? 54 : 44,
        child: GestureDetector(
          onTap: () => setState(() {
            _selectedSpark = isSelected ? null : spark;
          }),
          child: _SparkPin(color: color, selected: isSelected),
        ),
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard: don't hand flutter_map infinite/zero dimensions – it will
        // crash with 'picture != null' assertion inside the tile layer.
        if (!constraints.hasBoundedHeight ||
            constraints.maxHeight <= 0 ||
            !constraints.hasBoundedWidth ||
            constraints.maxWidth <= 0) {
          return const SizedBox.expand();
        }

        return Stack(
      children: [
        RepaintBoundary(
          child: FlutterMap(
          options: MapOptions(
            initialCenter: _bangaloreCenter,
            initialZoom: 13,
            onTap: (_, __) => setState(() => _selectedSpark = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.spark.app',
              maxZoom: 19,
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        ),

        // ── OSM attribution ──
        Positioned(
          bottom: _selectedSpark != null ? 128 : 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ),

        // ── Selected-spark bottom card ──
        if (_selectedSpark != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _SparkMapCard(
              spark: _selectedSpark!,
              onTap: () => widget.onSparkTap(_selectedSpark!),
              onClose: () => setState(() => _selectedSpark = null),
            ),
          ),
      ],
        );      // Stack
      },        // LayoutBuilder builder
    );          // LayoutBuilder
  }
}

// ── Pin widget ────────────────────────────────────────────────────────────────

class _SparkPin extends StatelessWidget {
  const _SparkPin({required this.color, required this.selected});
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: selected ? 20 : 16,
          height: selected ? 20 : 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: selected ? 12 : 6,
                spreadRadius: selected ? 3 : 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 2,
          height: selected ? 12 : 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

// ── Bottom card shown when a spark pin is tapped ──────────────────────────────

class _SparkMapCard extends StatelessWidget {
  const _SparkMapCard({
    required this.spark,
    required this.onTap,
    required this.onClose,
  });
  final Spark spark;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: spark.category.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                spark.category.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: spark.category.accentColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spark.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          spark.location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Time badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spark.timeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
