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
  bool _heroExpanded = true;
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderSection(
                        selectedLocation: selectedLocation,
                        onLocationTap: () =>
                            _showLocationSelector(context),
                        onRadiusTap: () =>
                            _showPreferencesSheet(context),
                        radius: radius,
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _heroExpanded = !_heroExpanded),
                        child: AnimatedCrossFade(
                          duration: const Duration(milliseconds: 280),
                          crossFadeState: _heroExpanded
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: Stack(
                            children: [
                              const _HeroPanel(),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.expand_less,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'Hide',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          secondChild: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F426F),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.explore,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Find plans happening around you',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Spacer(),
                                Icon(
                                  Icons.expand_more,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (showMyActivity) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ActivityScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.history_toggle_off,
                                  color: Color(0xFF2F426F),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'My Activity',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Open',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2F426F),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: Color(0xFF2F426F),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else
                        const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'What\'s happening',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _showPreferencesSheet(context),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _InlineSearchBar(
                        initialValue: query,
                        onChanged: (value) {
                          setState(() {
                            query = value.trim().toLowerCase();
                          });
                        },
                        onSubmitted: (value) {
                          setState(() {
                            query = value.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final tab in [
                              ('all', 'All'),
                              ('now', 'Now'),
                              ('soon', 'Soon'),
                              ('tonight', 'Tonight'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _TimingTab(
                                  label: tab.$2,
                                  selected: _timingTab == tab.$1,
                                  onTap: () => setState(
                                    () => _timingTab = tab.$1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
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
                      const SizedBox(height: 12),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
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
                      if (loading) const SizedBox(height: 4),
                      const _LiveHeader(),
                      const SizedBox(height: 10),
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
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NearbyCard(
                        spark: spark,
                        ctaLabel: joinedSparkIds.contains(spark.id)
                            ? 'Open →'
                            : 'Join →',
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
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
    );
  }
}

class _TimingTab extends StatelessWidget {
  const _TimingTab({
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2F426F) : const Color(0xFFF1F4FB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.selectedLocation,
    required this.onLocationTap,
    required this.onRadiusTap,
    required this.radius,
  });

  final String selectedLocation;
  final VoidCallback onLocationTap;
  final VoidCallback onRadiusTap;
  final int radius;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
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
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Saurav',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onLocationTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          selectedLocation,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '·',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onRadiusTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${radius}km radius',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.tune_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {},
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineSearchBar extends StatefulWidget {
  const _InlineSearchBar({
    required this.initialValue,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  State<_InlineSearchBar> createState() => _InlineSearchBarState();
}

class _InlineSearchBarState extends State<_InlineSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  static const _quickTags = [
    'Cricket', 'Coffee', 'Study', 'Cycling', 'Drive', 'Badminton',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _focused ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? const Color(0xFF2F426F) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 18,
                color: _focused
                    ? const Color(0xFF2F426F)
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.search,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Search plans, sports, study, ride',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (_focused && _controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (_focused && _controller.text.isEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _quickTags
                  .map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _controller.text = tag.toLowerCase();
                          widget.onChanged(tag.toLowerCase());
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2F426F),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2F426F),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PillLabel(label: 'LIVE IN YOUR AREA'),
          SizedBox(height: 12),
          Text(
            'Find plans happening around you',
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Spark helps people discover tiny plans nearby\nwithout the noise of a big social feed.',
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: Color(0xFFD5E0FA),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BehaviorPill(label: 'Nearby'),
              _BehaviorPill(label: 'Happening soon'),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniSpark(
                  category: 'SPORTS',
                  title: 'Cricket game',
                  when: 'Tonight',
                  categoryColor: Color(0xFF31C48D),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _MiniSpark(
                  category: 'TRANSIT',
                  title: 'Airport split',
                  when: 'In 45 min',
                  categoryColor: Color(0xFF7390FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Color(0xFFDCE3F5),
        ),
      ),
    );
  }
}

class _BehaviorPill extends StatelessWidget {
  const _BehaviorPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFE3ECFF),
        ),
      ),
    );
  }
}

class _MiniSpark extends StatelessWidget {
  const _MiniSpark({
    required this.category,
    required this.title,
    required this.when,
    required this.categoryColor,
  });

  final String category;
  final String title;
  final String when;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 98,
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 3, color: categoryColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        when,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2F426F),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF2F426F)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2F426F)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? Colors.white : AppColors.textPrimary,
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

  static const _avatarColors = [
    Color(0xFF6366F1), Color(0xFF0EA5E9), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF8B5CF6),
  ];
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

  static Color _categoryColor(SparkCategory cat) => switch (cat) {
        SparkCategory.sports => const Color(0xFF86EFAC),
        SparkCategory.study => const Color(0xFF93C5FD),
        SparkCategory.ride => const Color(0xFFC4B5FD),
        SparkCategory.events => const Color(0xFFFDBA74),
        SparkCategory.hangout => const Color(0xFFF9A8D4),
      };

  static IconData _categoryIcon(SparkCategory cat) => switch (cat) {
        SparkCategory.sports => Icons.sports_soccer,
        SparkCategory.study => Icons.menu_book_outlined,
        SparkCategory.ride => Icons.directions_car_filled_outlined,
        SparkCategory.events => Icons.event_outlined,
        SparkCategory.hangout => Icons.groups_2_outlined,
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
      final ci = (seed + i * 7) % _avatarColors.length;
      final ii = (seed + i * 13) % _avatarInitials.length;
      return (_avatarColors[ci], _avatarInitials[ii]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spark = widget.spark;
    final catColor = _categoryColor(spark.category);
    final icon = _categoryIcon(spark.category);
    final isLowSpots = spark.spotsLeft <= 2;
    final isJoined = widget.ctaLabel.startsWith('Open');
    final avatars = _avatars();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: catColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            icon,
                            color: const Color(0xFF3E5E9E),
                            size: 22,
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
                              const SizedBox(height: 3),
                              Text(
                                '${spark.location}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLowSpots
                                          ? const Color(0xFFFEE2E2)
                                          : const Color(0xFFDCFCE7),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _countdown(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isLowSpots
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _AvatarStack(avatars: avatars),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${avatars.length} joining',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isLowSpots
                                    ? '${spark.spotsLeft} spots left · ${spark.distanceLabel}'
                                    : spark.distanceLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isLowSpots
                                      ? const Color(0xFFDC2626)
                                      : AppColors.textSecondary,
                                ),
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
                            isJoined ? 'Open' : 'Join',
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
                    color: Colors.white,
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
      children: [
        const Text(
          'Happening nearby',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 8,
            height: 8,
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
            'Your spark could be what someone nearby is looking for right now.',
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
