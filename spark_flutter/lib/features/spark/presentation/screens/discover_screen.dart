import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../domain/spark.dart';
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
      ref.read(sparkDataControllerProvider).refreshNearby(
        radiusKm: radius.toDouble(),
      );
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
    await ref.read(sparkDataControllerProvider).refreshNearby(
      radiusKm: radius.toDouble(),
    );
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
    final showMyActivity = joinedSparks.isNotEmpty || createdSparks.isNotEmpty;
    final createdSparkIds = createdSparks.map((spark) => spark.id).toSet();
    final discoverableSparks = sparks.where((spark) {
      final isMineById = createdSparkIds.contains(spark.id);
      final isMineByHost = spark.createdBy == currentUserId;
      return !isMineById && !isMineByHost;
    }).toList();
    final filtered = _applyFilters(discoverableSparks);

    return Scaffold(
      backgroundColor: Colors.white,
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
                      // ── Category chips + activity pill ────────────
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _CategoryChip(
                                    label: 'All',
                                    icon: Icons.apps_outlined,
                                    selected: selectedCategory == null,
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
                                          onTap: () => setState(() {
                                            selectedCategory = category;
                                          }),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            color: const Color(0xFFDDE3F0),
                          ),
                          GestureDetector(
                            onTap: () => _showPreferencesSheet(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                size: 15,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Section header ────────────────────────────
                      Row(
                        children: [
                          const _LiveHeader(),
                          if (showMyActivity) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ActivityScreen(),
                                ),
                              ),
                              child: const Text(
                                'My activity →',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFCA5A5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 16,
                                color: Color(0xFFB91C1C),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Could not refresh sparks. Pull down to retry.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7F1D1D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (filtered.isEmpty && !loading)
                        const _EmptyState(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: filtered.isEmpty
                      ? const SizedBox.shrink()
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE4E7EC),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < filtered.length; i++) ...[
                                  if (i > 0)
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0xFFEBEDF0),
                                    ),
                                  _NearbyCard(
                                    spark: filtered[i],
                                    ctaLabel: joinedSparkIds
                                            .contains(filtered[i].id)
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
          ref.read(sparkDataControllerProvider).refreshNearby(
            radiusKm: radius.toDouble(),
          );
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
                          onSelected: (_) => setSheetState(
                            () => draftCategory = category,
                          ),
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
                  ref.read(sparkDataControllerProvider).refreshNearby(
                    radiusKm: draftRadius.toDouble(),
                  );
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
const double _kExpandedHeight = 212.0;
const double _kCollapsedHeight = 96.0;

class _DiscoverHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DiscoverHeaderDelegate({
    required this.selectedLocation,
    required this.radius,
    required this.onLocationTap,
    required this.onRadiusTap,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String selectedLocation;
  final int radius;
  final VoidCallback onLocationTap;
  final VoidCallback onRadiusTap;
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
    final t =
        (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
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
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String selectedLocation;
  final int radius;
  final VoidCallback onLocationTap;
  final VoidCallback onRadiusTap;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  State<_HeroPanel> createState() => _HeroPanelState();
}

class _HeroPanelState extends State<_HeroPanel>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

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
    _shimmerCtrl.dispose();
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
        animation: Listenable.merge([_shimmerCtrl, _floatCtrl]),
        builder: (context, child) {
          final shimmerT = _shimmerCtrl.value;
          final floatT = _floatCtrl.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + shimmerT * 0.3, -0.5),
                end: Alignment(1.0 + shimmerT * 0.3, 1.0),
                colors: const [
                  Color(0xFF1A2D50),
                  Color(0xFF243B6A),
                  Color(0xFF1E3358),
                  Color(0xFF2A4575),
                ],
                stops: [
                  0.0,
                  0.3 + shimmerT * 0.1,
                  0.6 + shimmerT * 0.05,
                  1.0,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -30 + floatT * 15,
                  top: -20 + floatT * 10,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF60A5FA).withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -40 + floatT * 8,
                  bottom: -10 + floatT * 12,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF86EFAC).withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 60 + floatT * 5,
                  bottom: 30 - floatT * 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15 + floatT * 0.1),
                    ),
                  ),
                ),
                Positioned(
                  left: 40 - floatT * 6,
                  top: 30 + floatT * 4,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF86EFAC).withValues(alpha: 0.2 + floatT * 0.15),
                    ),
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _entryCtrl,
            curve: Curves.easeOut,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        '$_greeting, Saurav',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.65),
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: widget.onLocationTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: const Color(0xFF86EFAC).withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.selectedLocation,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '·',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.radius}km',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Plans happening\nnear you, right now.',
                  style: TextStyle(
                    fontSize: 27,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Manrope',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
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
        pageBuilder: (_, __, ___) =>
            _SearchScreen(initialQuery: currentQuery),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
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
                  color: Colors.black.withValues(
                    alpha: hasQuery ? 0.75 : 0.28,
                  ),
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
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialQuery);
  String _query = '';

  static const _recentTags = [
    'Cricket', 'Coffee', 'Study', 'Cycling', 'Drive', 'Badminton',
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
      backgroundColor: Colors.white,
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
                      color: Colors.black87,
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
                      onChanged: (v) =>
                          setState(() => _query = v.trim()),
                      onSubmitted: _submit,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF5F7FC),
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
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE3F0),
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE3F0),
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
                            : const Color(0xFFF0F3FA),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isActive
                              ? AppColors.accent
                              : const Color(0xFFDDE3F0),
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
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
  });

  final String selectedLocation;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2D50), Color(0xFF243B6A)],
        ),
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
                color: const Color(0xFF86EFAC).withValues(alpha: 0.8),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.accent : const Color(0xFFD1D5DB),
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
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF374151),
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
              color: const Color(0xFFE4EBFA),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.explore_off_outlined,
              size: 30,
              color: Color(0xFF3E5E9E),
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

  static const _iconBg = Color(0xFFF2F4F8);
  static const _iconFg = Color(0xFF3D5070);

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
      return (const Color(0xFFE8ECF5), _avatarInitials[ii]);
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

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: _iconFg, size: 22),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spark.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: isNow ? AppColors.success : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _countdown(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isNow ? AppColors.success : const Color(0xFF9CA3AF),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('·', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
                      ),
                      Icon(Icons.near_me_rounded, size: 11, color: const Color(0xFF9CA3AF)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          spark.distanceLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _AvatarStack(avatars: avatars),
                      const SizedBox(width: 5),
                      Text(
                        '${spark.participants.length} joining',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      if (isLowSpots) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${spark.spotsLeft} left',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
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
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.ctaLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isJoined
                      ? const Color(0xFF9CA3AF)
                      : AppColors.accent,
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
  const _AvatarStack({required this.avatars});
  final List<(Color, String)> avatars;

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    const overlap = 11.0;
    return SizedBox(
      width: size + (avatars.length - 1) * overlap,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < avatars.length; i++)
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
            color: Color(0xFF111827),
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
                    color: AppColors.success.withValues(alpha: 0.4 * _pulse.value),
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
        border: Border.all(color: const Color(0xFFE4E7EC), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 22,
                color: AppColors.accent,
              ),
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
