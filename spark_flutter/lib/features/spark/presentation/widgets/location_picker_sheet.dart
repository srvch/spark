import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/places_autocomplete_service.dart';

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    required this.title,
    required this.selectedLocation,
    required this.savedLocations,
    required this.recentLocations,
    required this.catalogLocations,
    required this.placesService,
    required this.onSelect,
  });

  final String title;
  final String selectedLocation;
  final List<String> savedLocations;
  final List<String> recentLocations;
  final List<String> catalogLocations;
  final PlacesAutocompleteService placesService;
  final ValueChanged<String> onSelect;

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;
  bool _isLoading = false;
  bool _resolvingCurrentLocation = false;
  String? _apiError;
  List<PlaceSuggestion> _apiSuggestions = const [];
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _results {
    final merged = <String>{
      ...widget.recentLocations,
      ...widget.savedLocations,
      ...widget.catalogLocations,
    }.toList();

    if (_query.isEmpty) {
      return merged.take(8).toList();
    }

    final q = _normalize(_query);
    final scored = <({String place, int score})>[];

    for (final place in merged) {
      final normalized = _normalize(place);
      if (normalized.startsWith(q)) {
        scored.add((place: place, score: 0));
        continue;
      }
      if (normalized.contains(q)) {
        scored.add((place: place, score: 1));
        continue;
      }
      if (_isSubsequence(q, normalized)) {
        scored.add((place: place, score: 2));
        continue;
      }
      final distance = _levenshtein(q, normalized);
      final maxDistance = q.length >= 8 ? 3 : 2;
      if (distance <= maxDistance) {
        scored.add((place: place, score: 3 + distance));
      }
    }

    scored.sort((a, b) => a.score.compareTo(b.score));
    return scored.map((e) => e.place).take(12).toList();
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    setState(() {
      _query = query;
      _apiError = null;
      if (query.isEmpty) {
        _apiSuggestions = const [];
        _isLoading = false;
      }
    });

    _debounce?.cancel();
    if (query.isEmpty || !widget.placesService.isConfigured) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final callId = ++_requestId;
      setState(() => _isLoading = true);
      try {
        final suggestions = await widget.placesService.search(input: query);
        if (!mounted || callId != _requestId) return;
        setState(() {
          _apiSuggestions = suggestions;
          _apiError = null;
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted || callId != _requestId) return;
        setState(() {
          _apiSuggestions = const [];
          _apiError = 'Could not fetch location suggestions';
          _isLoading = false;
        });
      }
    });
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _isSubsequence(String needle, String haystack) {
    if (needle.isEmpty) return true;
    var i = 0;
    var j = 0;
    while (i < needle.length && j < haystack.length) {
      if (needle[i] == haystack[j]) i++;
      j++;
    }
    return i == needle.length;
  }

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(
      a.length + 1,
      (i) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

  Future<void> _useCurrentLocation() async {
    if (_resolvingCurrentLocation) return;
    setState(() => _resolvingCurrentLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location services and try again.')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is needed to use current location.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final resolved = _formatPlacemark(placemarks);
      if (!mounted) return;
      widget.onSelect(resolved);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not fetch current location right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingCurrentLocation = false);
      }
    }
  }

  String _formatPlacemark(List<Placemark> marks) {
    if (marks.isEmpty) return widget.selectedLocation;
    final p = marks.first;
    final parts = <String>[
      if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
      if ((p.subAdministrativeArea ?? '').trim().isNotEmpty)
        p.subAdministrativeArea!.trim(),
      if ((p.administrativeArea ?? '').trim().isNotEmpty)
        p.administrativeArea!.trim(),
    ];
    if (parts.isNotEmpty) {
      return parts.take(2).join(', ');
    }
    final area = (p.subLocality ?? '').trim();
    if (area.isNotEmpty) return area;
    return widget.selectedLocation;
  }

  static const _kNavy = AppColors.accent;

  /// Opens a full-screen dialog (not a sheet) so the TextField lives at root
  /// Navigator coordinates — iOS renders its input toolbar correctly there.
  Future<void> _openSearchDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _LocationSearchDialog(
        initialQuery: _query,
        placesService: widget.placesService,
        localItems: _results,
      ),
    );
    if (result != null && mounted) {
      _searchController.text = result;
      _onSearchChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasApiKey = widget.placesService.isConfigured;
    final localResults = _results;
    final apiResults = _apiSuggestions;
    final showApiMode = _query.isNotEmpty && hasApiKey;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // ── Header row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select a location',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Search bar (visual tap target — no inline TextField) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _openSearchDialog,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDDE3F0), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: _kNavy),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _query.isEmpty ? 'Search location' : _query,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _query.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: _query.isEmpty
                                ? AppColors.textSecondary
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      else if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _onSearchChanged('');
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
              ),
            ),
            const SizedBox(height: 20),
            // ── Scrollable body ────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  // ── Current location section ──────────────────────
                  if (_query.isEmpty) ...[
                    const Text(
                      'Current location',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.selectedLocation,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _useCurrentLocation,
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDE3F0), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _resolvingCurrentLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _kNavy,
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location_rounded,
                                    size: 16,
                                    color: _kNavy,
                                  ),
                            const SizedBox(width: 8),
                            Text(
                              _resolvingCurrentLocation
                                  ? 'Detecting location…'
                                  : 'Use current location',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // ── Saved / search results section ────────────────
                  if (_query.isNotEmpty) ...[
                    // "Use exactly what user typed" row
                    _LocationRow(
                      label: 'Use "$_query"',
                      icon: Icons.edit_location_alt_outlined,
                      onTap: () => widget.onSelect(_query),
                    ),
                    if (showApiMode && apiResults.isNotEmpty)
                      const _SectionDivider(),
                  ],
                  if (_query.isEmpty) ...[
                    const Text(
                      'Saved areas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (showApiMode && apiResults.isNotEmpty)
                    ...apiResults.asMap().entries.map(
                          (e) => Column(
                            children: [
                              _LocationRow(
                                label: e.value.primaryText,
                                subtitle: e.value.secondaryText,
                                icon: Icons.navigation_rounded,
                                selected: false,
                                onTap: () =>
                                    widget.onSelect(e.value.primaryText),
                              ),
                              if (e.key < apiResults.length - 1)
                                const _SectionDivider(),
                            ],
                          ),
                        )
                  else ...[
                    if (localResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No areas found. Try a nearby neighbourhood name.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...localResults.asMap().entries.map(
                            (e) => Column(
                              children: [
                                _LocationRow(
                                  label: e.value,
                                  icon: Icons.navigation_rounded,
                                  selected:
                                      e.value == widget.selectedLocation,
                                  onTap: () => widget.onSelect(e.value),
                                ),
                                if (e.key < localResults.length - 1)
                                  const _SectionDivider(),
                              ],
                            ),
                          ),
                  ],
                  if (_apiError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _apiError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ── Bottom CTA ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () {
                  // Show a simple prompt to type a custom area name
                  _searchController.clear();
                  _onSearchChanged('');
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _kNavy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Add new area',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
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

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.selected = false,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 18, color: AppColors.accent)
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0F3FA));
  }
}

// ── Location search dialog ─────────────────────────────────────────────────
// Lives at the root Navigator level so iOS keyboard toolbar coords are correct.
class _LocationSearchDialog extends StatefulWidget {
  const _LocationSearchDialog({
    required this.initialQuery,
    required this.placesService,
    required this.localItems,
  });

  final String initialQuery;
  final PlacesAutocompleteService placesService;
  final List<String> localItems;

  @override
  State<_LocationSearchDialog> createState() =>
      _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<_LocationSearchDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialQuery);
  String _query = '';
  bool _loading = false;
  List<PlaceSuggestion> _apiResults = const [];
  Timer? _debounce;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    final q = val.trim();
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _apiResults = const [];
        _loading = false;
      }
    });
    _debounce?.cancel();
    if (q.isEmpty || !widget.placesService.isConfigured) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final id = ++_reqId;
      setState(() => _loading = true);
      try {
        final res = await widget.placesService.search(input: q);
        if (!mounted || id != _reqId) return;
        setState(() {
          _apiResults = res;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || id != _reqId) return;
        setState(() => _loading = false);
      }
    });
  }

  List<String> get _filtered {
    if (_query.isEmpty) return widget.localItems.take(8).toList();
    final q = _query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return widget.localItems
        .where((s) =>
            s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').contains(q))
        .take(10)
        .toList();
  }

  void _pick(String value) => Navigator.of(context).pop(value);

  @override
  Widget build(BuildContext context) {
    final showApi = _query.isNotEmpty && widget.placesService.isConfigured;
    final items = showApi ? <String>[] : _filtered;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Search input ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FC),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                autofocus: true,
                                autocorrect: false,
                                enableSuggestions: false,
                                contextMenuBuilder: null,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (v) {
                                  if (v.trim().isNotEmpty) _pick(v.trim());
                                },
                                onChanged: _onChanged,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  hintText: 'Search location…',
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            if (_loading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: AppColors.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(null),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Results list ─────────────────────────────────────
              if (_query.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      // "Use exactly what was typed" row
                      _DialogRow(
                        label: 'Use "$_query"',
                        icon: Icons.edit_location_alt_outlined,
                        onTap: () => _pick(_query),
                      ),
                      if (showApi && _apiResults.isNotEmpty) ...[
                        const Divider(height: 1, color: Color(0xFFF0F3FA)),
                        ..._apiResults.map(
                          (s) => _DialogRow(
                            label: s.primaryText,
                            subtitle: s.secondaryText,
                            icon: Icons.navigation_rounded,
                            onTap: () => _pick(s.primaryText),
                          ),
                        ),
                      ] else if (!showApi && items.isNotEmpty) ...[
                        const Divider(height: 1, color: Color(0xFFF0F3FA)),
                        ...items.map(
                          (s) => _DialogRow(
                            label: s,
                            icon: Icons.navigation_rounded,
                            onTap: () => _pick(s),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: AppColors.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
}
