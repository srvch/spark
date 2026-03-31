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

  @override
  Widget build(BuildContext context) {
    final hasApiKey = widget.placesService.isConfigured;
    final localResults = _results;
    final apiResults = _apiSuggestions;
    final showApiMode = _query.isNotEmpty && hasApiKey;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Container(
                height: 46,
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
                        controller: _searchController,
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Search area, landmark, city',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location, color: Color(0xFF2F426F)),
                title: Text(
                  _resolvingCurrentLocation
                      ? 'Fetching current location...'
                      : 'Use current location',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  widget.selectedLocation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: _resolvingCurrentLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _useCurrentLocation,
              ),
              if (_query.isEmpty && widget.recentLocations.isNotEmpty) ...[
                const SizedBox(height: 2),
                const Text(
                  'Recent',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.recentLocations
                      .map(
                        (place) => ActionChip(
                          label: Text(place),
                          onPressed: () => widget.onSelect(place),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Locations',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (!hasApiKey)
                    const Text(
                      'Local mode',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      );
                    }

                    final items = <Widget>[];
                    if (_query.isNotEmpty) {
                      items.add(
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.edit_location_alt_outlined, size: 18),
                          title: Text(
                            'Use "$_query"',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          onTap: () => widget.onSelect(_query),
                        ),
                      );
                    }

                    if (showApiMode && apiResults.isNotEmpty) {
                      items.addAll(
                        apiResults.map(
                          (suggestion) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined, size: 18),
                            title: Text(
                              suggestion.primaryText,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: suggestion.secondaryText == null
                                ? null
                                : Text(
                                    suggestion.secondaryText!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                            onTap: () => widget.onSelect(suggestion.primaryText),
                          ),
                        ),
                      );
                    } else {
                      items.addAll(
                        localResults.map(
                          (place) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined, size: 18),
                            title: Text(
                              place,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: place == widget.selectedLocation
                                ? const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Color(0xFF2F426F),
                                  )
                                : null,
                            onTap: () => widget.onSelect(place),
                          ),
                        ),
                      );
                    }

                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No locations found. Try a nearby area name.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }

                    return ListView(children: items);
                  },
                ),
              ),
              if (_apiError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _apiError!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
