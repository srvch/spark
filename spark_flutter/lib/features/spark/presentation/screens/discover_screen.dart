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
                              height: 34,
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
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showPreferencesSheet(context),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: Colors.black54,
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF0FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'My activity →',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2F426F),
                                  ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final spark = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NearbyCard(
                        spark: spark,
                        ctaLabel: joinedSparkIds.contains(spark.id)
                            ? 'Chat'
                            : 'Join',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SparkDetailScreen(spark: spark),
                            ),
                          );
                        },
                      ),
                    );
                  },
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
                  backgroundColor: const Color(0xFF2F426F),
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

    return AnimatedSwitcher(
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
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
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
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: Container(
        color: const Color(0xFF2F426F),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: greeting (left) + bell (right) ──────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '$_greeting, Saurav',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontFamily: 'Manrope',
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 17,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ── Row 2: location · radius ────────────────────────────
            GestureDetector(
              onTap: onLocationTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    selectedLocation,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      '·',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${radius}km',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Row 3: headline ─────────────────────────────────────
            const Text(
              'Plans happening near you, right now.',
              style: TextStyle(
                fontSize: 22,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 16),
            // ── Row 4: search bar (white, inside navy) ──────────────
            _HeroBannerSearch(
              initialValue: searchQuery,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBannerSearch extends StatefulWidget {
  const _HeroBannerSearch({
    required this.initialValue,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_HeroBannerSearch> createState() => _HeroBannerSearchState();
}

class _HeroBannerSearchState extends State<_HeroBannerSearch> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: Colors.black.withValues(alpha: 0.28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary.withValues(alpha: 0.9),
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'Search plans, sports, study, ride…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withValues(alpha: 0.28),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _HeroCollapsed extends StatelessWidget {
  const _HeroCollapsed({
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
      color: const Color(0xFF2F426F),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name · location ──────────────────────────────────────
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
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 2),
              Text(
                selectedLocation,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Sticky search bar ────────────────────────────────────
          _HeroBannerSearch(
            initialValue: searchQuery,
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
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
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2F426F)
                : const Color(0xFFF0F1F5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : Colors.black45,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.black54,
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

  static const _avatarBg = Color(0xFFDDE3F0);
  static const _avatarFg = Color(0xFF2F426F);
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
      return (_avatarBg, _avatarInitials[ii]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spark = widget.spark;
    final icon = _categoryIcon(spark.category);
    final isLowSpots = spark.spotsLeft <= 2;
    final isJoined = widget.ctaLabel == 'Chat';
    final avatars = _avatars();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: const Color(0xFFE8ECF4)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F3FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: const Color(0xFF2F426F),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spark.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _countdown(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 5),
                                    child: Text(
                                      '·',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.near_me_rounded,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      spark.distanceLabel,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (isLowSpots) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 5),
                                      child: Text(
                                        '·',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${spark.spotsLeft} left',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2F426F),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isJoined
                                ? const Color(0xFFE4EBFA)
                                : AppColors.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.ctaLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isJoined
                                  ? AppColors.accent
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
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

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars});
  final List<(Color, String)> avatars;

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    const overlap = 10.0;
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
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F426F),
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
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontFamily: 'Manrope',
          ),
        ),
        const SizedBox(width: 7),
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0DCFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nothing nearby? Start one.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start a plan. Someone nearby might join.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(bottomTabProvider.notifier).state = 1;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'Create a spark',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
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
