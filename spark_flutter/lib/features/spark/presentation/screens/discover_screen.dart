import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../domain/spark.dart';
import '../controllers/spark_controller.dart';
import 'activity_screen.dart';
import 'spark_detail_screen.dart';
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
  String timingPref = 'any';
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    Future.microtask(() {
      ref.read(sparkDataControllerProvider).refreshNearby(
        radiusKm: radius.toDouble(),
      );
    });
  }

  @override
  void dispose() {
    _scrollController?.dispose();
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
              (timingPref == 'any' ||
                  (timingPref == '1h' && spark.startsInMinutes <= 60) ||
                  (timingPref == '2h' && spark.startsInMinutes <= 120)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    _scrollController ??= ScrollController();
    final sparks = ref.watch(sparksProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final selectedLocation = ref.watch(selectedLocationProvider);
    final loading = ref.watch(sparksLoadingProvider);
    final loadingMore = ref.watch(sparksLoadingMoreProvider);
    final loadError = ref.watch(sparksErrorProvider);
    final hasMoreRemote = ref.watch(nearbyHasMoreProvider);
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
    final showLoadMore =
        filtered.length >= _pageSize && hasMoreRemote && !loadingMore;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SPARK',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Nearby plans,\nmade easy.',
                                style: TextStyle(
                                  fontSize: 23,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 172),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _showLocationSelector(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          selectedLocation,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(Icons.keyboard_arrow_down, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _HeroPanel(),
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
                      children: [
                        const Text(
                          'Browse sparks',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _showPreferencesSheet(context),
                          child: const Text(
                            'Preferences',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
                    if (timingPref != 'any') ...[
                      const SizedBox(height: 4),
                      Text(
                        timingPref == '1h'
                            ? 'Timing: next 1 hour'
                            : 'Timing: next 2 hours',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 92,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryTile(
                            category: SparkCategory.sports,
                            labelOverride: 'All',
                            iconOverride: Icons.apps_outlined,
                            selected: selectedCategory == null,
                            onTap: () => setState(() {
                              selectedCategory = null;
                            }),
                          ),
                          ...SparkCategory.values
                              .where((c) => c != SparkCategory.hangout)
                              .map(
                                (category) => _CategoryTile(
                                  category: category,
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
                          border: Border.all(color: const Color(0xFFFCA5A5)),
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
                                'Could not refresh sparks. Pull to retry from Preferences.',
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
                    const Text(
                      'Happening nearby',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'No sparks match these filters yet.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
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
                      ctaLabel: joinedSparkIds.contains(spark.id) ? 'Open →' : 'Join →',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SparkDetailScreen(spark: spark),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (filtered.isNotEmpty && loadingMore)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    if (showLoadMore)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            ref
                                .read(sparkDataControllerProvider)
                                .fetchNextNearbyPage(
                                  radiusKm: radius.toDouble(),
                                );
                          },
                          child: const Text(
                            'LOAD MORE SPARKS',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    if (filtered.isNotEmpty && !showLoadMore && !loadingMore)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'You are all caught up nearby.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const _WhySection(),
                  ],
                ),
              ),
            ),
          ],
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
    var draftTiming = timingPref;

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
                children: [
                  ChoiceChip(
                    label: const Text('Any time'),
                    selected: draftTiming == 'any',
                    onSelected: (_) => setSheetState(() => draftTiming = 'any'),
                  ),
                  ChoiceChip(
                    label: const Text('Next 1 hour'),
                    selected: draftTiming == '1h',
                    onSelected: (_) => setSheetState(() => draftTiming = '1h'),
                  ),
                  ChoiceChip(
                    label: const Text('Next 2 hours'),
                    selected: draftTiming == '2h',
                    onSelected: (_) => setSheetState(() => draftTiming = '2h'),
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
                    timingPref = draftTiming;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
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
        ],
      ),
    );
  }

  @override
  void dispose() {
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
    return Container(
      height: 98,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: categoryColor,
            ),
          ),
          const SizedBox(height: 6),
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
          Text(
            when,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
    this.labelOverride,
    this.iconOverride,
  });

  final SparkCategory category;
  final bool selected;
  final VoidCallback onTap;
  final String? labelOverride;
  final IconData? iconOverride;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 74,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2F426F) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                iconOverride ?? category.icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                labelOverride ?? category.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.spark,
    required this.onTap,
    required this.ctaLabel,
  });

  final Spark spark;
  final VoidCallback onTap;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    final icon = switch (spark.category) {
      SparkCategory.sports => Icons.sports_soccer,
      SparkCategory.study => Icons.menu_book_outlined,
      SparkCategory.ride => Icons.directions_car_filled_outlined,
      SparkCategory.events => Icons.event_outlined,
      SparkCategory.hangout => Icons.groups_2_outlined,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE4EBFA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF3E5E9E)),
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
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${spark.timeLabel} · ${spark.location}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${spark.spotsLeft} spots left • ${spark.distanceLabel}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              ctaLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhySection extends StatelessWidget {
  const _WhySection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        'Trusted for real-time plans,\nnear you.',
        style: TextStyle(
          fontSize: 33,
          height: 1.02,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
