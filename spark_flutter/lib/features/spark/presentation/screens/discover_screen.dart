import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/navigation/root_shell.dart';
import '../../domain/spark.dart';
import '../controllers/spark_controller.dart';
import 'spark_detail_screen.dart';
import 'activity_screen.dart';
import '../widgets/location_picker_sheet.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF2F426F);
const _kNavyLight = Color(0xFFEAF0FF);
const _kSurface = Color(0xFFF7F8FC);
const _kBorder = Color(0xFFE8EBF4);
const _kMuted = Color(0xFF9CA3AF);
const _kGreen = Color(0xFF22C55E);

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  SparkCategory? _selectedCategory = SparkCategory.sports;
  int _radius = 5;
  String _query = '';
  String _timingTab = 'all';
  late final ScrollController _scrollController;
  bool _isInfiniteScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    Future.microtask(
      () => ref.read(sparkDataControllerProvider).refreshNearby(
            radiusKm: _radius.toDouble(),
          ),
    );
  }

  void _onScroll() {
    if (_isInfiniteScrolling) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      final hasMore = ref.read(nearbyHasMoreProvider);
      final loadingMore = ref.read(sparksLoadingMoreProvider);
      if (hasMore && !loadingMore) {
        setState(() => _isInfiniteScrolling = true);
        ref
            .read(sparkDataControllerProvider)
            .fetchNextNearbyPage(radiusKm: _radius.toDouble())
            .whenComplete(() {
          if (mounted) setState(() => _isInfiniteScrolling = false);
        });
      }
    }
  }

  Future<void> _onRefresh() =>
      ref.read(sparkDataControllerProvider).refreshNearby(
            radiusKm: _radius.toDouble(),
          );

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  List<Spark> _applyFilters(List<Spark> sparks) {
    return sparks.where((s) {
      final catMatch = _selectedCategory == null || s.category == _selectedCategory;
      final distMatch = s.distanceKm <= _radius;
      final qMatch = _query.isEmpty ||
          s.title.toLowerCase().contains(_query) ||
          s.location.toLowerCase().contains(_query) ||
          s.category.label.toLowerCase().contains(_query);
      final timeMatch = _timingTab == 'all' ||
          (_timingTab == 'now' && s.startsInMinutes <= 30) ||
          (_timingTab == 'soon' && s.startsInMinutes <= 120) ||
          (_timingTab == 'tonight' && s.startsInMinutes <= 480);
      return catMatch && distMatch && qMatch && timeMatch;
    }).toList();
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
    final createdSparkIds = createdSparks.map((s) => s.id).toSet();

    final discoverable = sparks.where((s) {
      return !createdSparkIds.contains(s.id) && s.createdBy != currentUserId;
    }).toList();
    final filtered = _applyFilters(discoverable);
    final urgent = filtered.where((s) => s.startsInMinutes <= 30).toList();

    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: _kNavy,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Top header ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _TopHeader(
                  selectedLocation: selectedLocation,
                  radius: _radius,
                  onLocationTap: () => _showLocationSelector(context),
                  onFilterTap: () => _showPreferencesSheet(context),
                ),
              ),
              // ── Search bar ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _SearchBar(
                    initialValue: _query,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
              ),
              // ── Category strip ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                  child: _CategoryStrip(
                    selected: _selectedCategory,
                    onSelect: (cat) => setState(() => _selectedCategory = cat),
                    onFilterTap: () => _showPreferencesSheet(context),
                  ),
                ),
              ),
              // ── Error banner ───────────────────────────────────────
              if (loadError != null && loadError.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _ErrorBanner(message: loadError),
                  ),
                ),
              // ── Loading bar ────────────────────────────────────────
              if (loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: _kNavy,
                      backgroundColor: Color(0xFFE8EBF4),
                    ),
                  ),
                ),
              // ── "Happening now" strip ──────────────────────────────
              if (urgent.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                  sliver: SliverToBoxAdapter(
                    child: _NowStrip(
                      sparks: urgent,
                      joinedSparkIds: joinedSparkIds,
                    ),
                  ),
                ),
              // ── Section header ─────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    showActivity: showMyActivity,
                    onActivityTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ActivityScreen(),
                      ),
                    ),
                  ),
                ),
              ),
              // ── Empty state ────────────────────────────────────────
              if (filtered.isEmpty && !loading)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverToBoxAdapter(child: _EmptyState()),
                ),
              // ── Card list ──────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final spark = filtered[index];
                    final isJoined = joinedSparkIds.contains(spark.id);
                    return _SparkCard(
                      spark: spark,
                      isJoined: isJoined,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SparkDetailScreen(spark: spark),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // ── Footer ─────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kNavy,
                            ),
                          ),
                        ),
                      if (filtered.isNotEmpty && !loadingMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            "You're all caught up nearby",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kMuted,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _CreateNudge(),
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

  // ── Sheets ────────────────────────────────────────────────────────────────

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
                radiusKm: _radius.toDouble(),
              );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showPreferencesSheet(BuildContext context) {
    var draftRadius = _radius;
    var draftCategory = _selectedCategory;
    var draftTiming = _timingTab;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kNavy,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 20),
                _SheetLabel('Distance — ${draftRadius}km'),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    activeTrackColor: _kNavy,
                    thumbColor: _kNavy,
                    inactiveTrackColor: const Color(0xFFE0E6F5),
                    overlayColor: _kNavy.withValues(alpha: 0.08),
                  ),
                  child: Slider(
                    value: draftRadius.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) => setSheet(() => draftRadius = v.round()),
                  ),
                ),
                const SizedBox(height: 16),
                const _SheetLabel('Category'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Any',
                      selected: draftCategory == null,
                      onTap: () => setSheet(() => draftCategory = null),
                    ),
                    ...SparkCategory.values
                        .where((c) => c != SparkCategory.hangout)
                        .map((c) => _FilterChip(
                              label: c.label,
                              selected: draftCategory == c,
                              onTap: () => setSheet(() => draftCategory = c),
                            )),
                  ],
                ),
                const SizedBox(height: 16),
                const _SheetLabel('Timing'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: draftTiming == 'all',
                      onTap: () => setSheet(() => draftTiming = 'all'),
                    ),
                    _FilterChip(
                      label: 'Now (≤30 min)',
                      selected: draftTiming == 'now',
                      onTap: () => setSheet(() => draftTiming = 'now'),
                    ),
                    _FilterChip(
                      label: 'Soon (≤2 hrs)',
                      selected: draftTiming == 'soon',
                      onTap: () => setSheet(() => draftTiming = 'soon'),
                    ),
                    _FilterChip(
                      label: 'Tonight',
                      selected: draftTiming == 'tonight',
                      onTap: () => setSheet(() => draftTiming = 'tonight'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _radius = draftRadius;
                        _selectedCategory = draftCategory;
                        _timingTab = draftTiming;
                      });
                      ref
                          .read(sparkDataControllerProvider)
                          .refreshNearby(radiusKm: draftRadius.toDouble());
                      Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      'Apply filters',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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

// ── Top header ────────────────────────────────────────────────────────────────

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.selectedLocation,
    required this.radius,
    required this.onLocationTap,
    required this.onFilterTap,
  });

  final String selectedLocation;
  final int radius;
  final VoidCallback onLocationTap;
  final VoidCallback onFilterTap;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kMuted,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Saurav',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _kNavy,
                    fontFamily: 'Manrope',
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onLocationTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: _kNavy,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selectedLocation,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kNavy,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: _kNavy,
                        ),
                        Container(
                          width: 1,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: _kBorder,
                        ),
                        Text(
                          '${radius}km',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: _kNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.initialValue, required this.onChanged});
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue);
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? _kNavy : _kBorder,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: _kNavy.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 18,
            color: _focused ? _kNavy : _kMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kNavy,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search plans, sports, study, ride',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kMuted,
                ),
              ),
            ),
          ),
          if (_focused && _ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                widget.onChanged('');
                setState(() {});
              },
              child: const Icon(Icons.close_rounded, size: 16, color: _kMuted),
            ),
        ],
      ),
    );
  }
}

// ── Category strip ────────────────────────────────────────────────────────────

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.selected,
    required this.onSelect,
    required this.onFilterTap,
  });

  final SparkCategory? selected;
  final ValueChanged<SparkCategory?> onSelect;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'All',
            icon: Icons.apps_rounded,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          ...SparkCategory.values
              .where((c) => c != SparkCategory.hangout)
              .map((c) => _Chip(
                    label: c.label,
                    icon: c.icon,
                    selected: selected == c,
                    onTap: () => onSelect(c),
                  )),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 16,
                color: _kNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _kNavy : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kNavy : _kBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : _kMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _kNavy,
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── "Happening now" strip ─────────────────────────────────────────────────────

class _NowStrip extends StatelessWidget {
  const _NowStrip({
    required this.sparks,
    required this.joinedSparkIds,
  });

  final List<Spark> sparks;
  final Set<String> joinedSparkIds;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _kGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Happening now',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: math.min(sparks.length, 8),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final spark = sparks[index];
              final isJoined = joinedSparkIds.contains(spark.id);
              return _NowCard(
                spark: spark,
                isJoined: isJoined,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SparkDetailScreen(spark: spark),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.spark,
    required this.isJoined,
    required this.onTap,
  });

  final Spark spark;
  final bool isJoined;
  final VoidCallback onTap;

  static IconData _icon(SparkCategory c) => switch (c) {
        SparkCategory.sports => Icons.directions_run_rounded,
        SparkCategory.study => Icons.auto_stories_rounded,
        SparkCategory.ride => Icons.drive_eta_rounded,
        SparkCategory.events => Icons.confirmation_number_outlined,
        SparkCategory.hangout => Icons.coffee_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final mins = spark.startsInMinutes;
    final timeText = mins <= 0
        ? 'Now'
        : mins < 60
            ? 'In ${mins}m'
            : 'In ${mins ~/ 60}h';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _icon(spark.category),
                    size: 16,
                    color: _kNavy,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              spark.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kNavy,
                fontFamily: 'Manrope',
                height: 1.25,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.near_me_rounded,
                  size: 11,
                  color: _kMuted,
                ),
                const SizedBox(width: 3),
                Text(
                  spark.distanceLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kMuted,
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

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatefulWidget {
  const _SectionHeader({
    required this.showActivity,
    required this.onActivityTap,
  });

  final bool showActivity;
  final VoidCallback onActivityTap;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader>
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
      children: [
        const Text(
          'Happening nearby',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _kNavy,
            fontFamily: 'Manrope',
          ),
        ),
        const SizedBox(width: 8),
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Spacer(),
        if (widget.showActivity)
          GestureDetector(
            onTap: widget.onActivityTap,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'My activity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kNavy,
                    fontFamily: 'Manrope',
                  ),
                ),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_rounded, size: 14, color: _kNavy),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Spark card ────────────────────────────────────────────────────────────────

class _SparkCard extends StatefulWidget {
  const _SparkCard({
    required this.spark,
    required this.isJoined,
    required this.onTap,
  });

  final Spark spark;
  final bool isJoined;
  final VoidCallback onTap;

  @override
  State<_SparkCard> createState() => _SparkCardState();
}

class _SparkCardState extends State<_SparkCard> {
  Timer? _timer;

  static const _initials = ['A', 'J', 'S', 'M', 'R', 'K', 'P', 'D'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted) setState(() {}); },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static IconData _icon(SparkCategory c) => switch (c) {
        SparkCategory.sports => Icons.directions_run_rounded,
        SparkCategory.study => Icons.auto_stories_rounded,
        SparkCategory.ride => Icons.drive_eta_rounded,
        SparkCategory.events => Icons.confirmation_number_outlined,
        SparkCategory.hangout => Icons.coffee_outlined,
      };

  String _countdown() {
    final m = widget.spark.startsInMinutes;
    if (m <= 0) return 'Now';
    if (m < 60) return 'In ${m}m';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? 'In ${h}h' : 'In ${h}h ${rem}m';
  }

  List<String> _avatarLetters() {
    final seed = widget.spark.id.hashCode.abs();
    final count = 2 + (seed % 3);
    return List.generate(
      count,
      (i) => _initials[(seed + i * 13) % _initials.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    final spark = widget.spark;
    final isUrgent = spark.startsInMinutes <= 15;
    final isLowSpots = spark.spotsLeft <= 2;
    final avatars = _avatarLetters();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUrgent
                ? const Color(0xFFD1FAE5)
                : _kBorder,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Icon container ───────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F3FA),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _icon(spark.category),
                      size: 22,
                      color: _kNavy,
                    ),
                  ),
                  if (isUrgent)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _kGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // ── Text content ─────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spark.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                        fontFamily: 'Manrope',
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: _kMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _countdown(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isUrgent
                                ? const Color(0xFF15803D)
                                : _kMuted,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: _kBorder,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.near_me_rounded,
                          size: 12,
                          color: _kMuted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            spark.distanceLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Mini avatar stack
                        SizedBox(
                          width: 18.0 + (avatars.length - 1) * 11.0,
                          height: 18,
                          child: Stack(
                            children: [
                              for (var i = 0; i < avatars.length; i++)
                                Positioned(
                                  left: i * 11.0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _kNavyLight,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                    child: Text(
                                      avatars[i],
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: _kNavy,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${spark.participants.length} joining',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                          ),
                        ),
                        if (isLowSpots) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${spark.spotsLeft} left',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
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
              // ── CTA button ───────────────────────────────────────
              _CtaButton(
                label: widget.isJoined ? 'Chat' : 'Join',
                isJoined: widget.isJoined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.isJoined});
  final String label;
  final bool isJoined;

  @override
  Widget build(BuildContext context) {
    if (isJoined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _kNavyLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Chat',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _kNavy,
            fontFamily: 'Manrope',
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Join',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontFamily: 'Manrope',
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _kNavyLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 32,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No sparks nearby yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kNavy,
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try widening your radius or changing\nthe category filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _kMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: Color(0xFFB91C1C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load sparks. Pull down to retry.',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7F1D1D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create nudge ──────────────────────────────────────────────────────────────

class _CreateNudge extends ConsumerWidget {
  const _CreateNudge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(bottomTabProvider.notifier).state = 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kNavyLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: _kNavy,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nothing nearby? Start one.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Create a spark and find people nearby.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _kMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _kMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preferences sheet helpers ─────────────────────────────────────────────────

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _kNavy,
        fontFamily: 'Manrope',
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kNavy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kNavy : _kBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _kNavy,
            fontFamily: 'Manrope',
          ),
        ),
      ),
    );
  }
}
