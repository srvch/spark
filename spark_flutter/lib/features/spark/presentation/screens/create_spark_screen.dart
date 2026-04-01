import 'dart:async';
// ignore_for_file: unused_element, unused_field, prefer_final_fields

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../../shared/widgets/invite_friends_sheet.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/spark.dart';
import '../controllers/spark_controller.dart';
import '../widgets/location_picker_sheet.dart';
import 'spark_detail_screen.dart';

class CreateSparkScreen extends ConsumerStatefulWidget {
  const CreateSparkScreen({super.key});

  @override
  ConsumerState<CreateSparkScreen> createState() => _CreateSparkScreenState();
}

class _CreateSparkScreenState extends ConsumerState<CreateSparkScreen> {
  final TextEditingController _planController = TextEditingController(
    text: 'Cricket at 6 near Central Park',
  );
  final TextEditingController _manualTitleController = TextEditingController();
  final TextEditingController _manualLocationController = TextEditingController();
  final TextEditingController _manualSpotsController = TextEditingController(text: '2');
  final TextEditingController _manualNoteController = TextEditingController();

  Timer? _aiDebounce;
  _InferredPlan? _aiInferred;
  bool _isAiParsing = false;
  bool _isAiUnavailable = false;
  String _lastAiInput = '';
  String _lastAiLocation = '';
  String? _lastSeenSelectedLocation;
  String _lastPlanText = '';
  late final SpeechToText _speechToText;
  bool _speechReady = false;
  bool _isListening = false;
  Timer? _speechSilenceTimer;
  String _lastVoiceTranscript = '';

  bool _isManualMode = true;
  DateTime? _autoTimeOverride;
  int? _autoSpotsOverride;
  String? _autoLocationOverride;
  String? _autoNoteOverride;
  late DateTime _manualSelectedDate;
  late int _manualHour;
  late int _manualMinute;
  late String _manualPeriod;
  SparkCategory _manualCategory = SparkCategory.sports;
  bool _manualOpenGroup = false;
  bool _previewExpanded = false;

  @override
  void initState() {
    super.initState();
    _speechToText = SpeechToText();
    final now = DateTime.now();
    _manualSelectedDate = DateTime(now.year, now.month, now.day);
    _manualHour = _to12Hour(now.hour);
    _manualMinute = now.minute;
    _manualPeriod = now.hour >= 12 ? 'PM' : 'AM';
    _planController.addListener(_onPlanChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initSpeech();
      _scheduleAiParse();
      _hydrateManualFromAuto(_effectiveAutoPlan());
    });
  }

  @override
  void dispose() {
    _aiDebounce?.cancel();
    _speechSilenceTimer?.cancel();
    _speechToText.stop();
    _planController.removeListener(_onPlanChanged);
    _planController.dispose();
    _manualTitleController.dispose();
    _manualLocationController.dispose();
    _manualSpotsController.dispose();
    _manualNoteController.dispose();
    super.dispose();
  }

  void _onPlanChanged() {
    final current = _planController.text.trim();
    if (current != _lastPlanText) {
      _lastPlanText = current;
      _autoTimeOverride = null;
      _autoSpotsOverride = null;
      _autoLocationOverride = null;
      _autoNoteOverride = null;
    }
    setState(() {});
    _scheduleAiParse();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speechToText.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() => _isListening = false);
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
      );
      if (!mounted) return;
      setState(() => _speechReady = available);
    } catch (_) {
      if (!mounted) return;
      setState(() => _speechReady = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLocation = ref.watch(selectedLocationProvider);
    if (_lastSeenSelectedLocation != selectedLocation) {
      _lastSeenSelectedLocation = selectedLocation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleAiParse();
      });
    }

    final manualPlan = _manualDraft();
    final validationMessage = _manualValidationMessage();
    final ctaHint = null;
    final dynamicSuggestions = _smartSuggestions(selectedLocation);
    final manualLocation = _manualLocationController.text.trim().isEmpty
        ? selectedLocation
        : _manualLocationController.text.trim();
    final isNearYou =
        _manualLocationController.text.trim().isEmpty || manualLocation == selectedLocation;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CreateScreenHeader(category: _manualCategory),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: _SectionCard(
                    accentColor: _categoryAccentColor(_manualCategory),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        _LabeledField(
                          label: 'Title',
                          child: TextField(
                            controller: _manualTitleController,
                            onChanged: (_) => setState(() {}),
                            maxLines: 1,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Cricket at 6 near Central Park',
                            ),
                          ),
                        ),
                        if (_manualTitleController.text.trim().isEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: dynamicSuggestions
                                .take(1)
                                .map(
                                  (label) => _SuggestionChip(
                                    label: label,
                                    onTap: () {
                                      _manualTitleController.text = label;
                                      _manualTitleController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: _manualTitleController.text.length),
                                      );
                                      setState(() {});
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: SparkCategory.values
                                .map(
                                  (c) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(c.label),
                                      showCheckmark: false,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      selected: c == _manualCategory,
                                      onSelected: (_) => setState(() {
                                        _manualCategory = c;
                                        if (_manualCategory == SparkCategory.ride) {
                                          _manualOpenGroup = false;
                                        }
                                      }),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Time',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _QuickChoiceChip(
                                      label: 'Now',
                                      selected: _manualStartsAt().difference(DateTime.now()).inMinutes <= 5,
                                      onTap: () => _setManualTimeFromDateTime(DateTime.now().add(const Duration(minutes: 2))),
                                    ),
                                    const SizedBox(width: 8),
                                    _QuickChoiceChip(
                                      label: '30 min',
                                      selected: _manualStartsAt().difference(DateTime.now()).inMinutes > 5 &&
                                          _manualStartsAt().difference(DateTime.now()).inMinutes <= 35,
                                      onTap: () => _setManualTimeFromDateTime(DateTime.now().add(const Duration(minutes: 30))),
                                    ),
                                    const SizedBox(width: 8),
                                    _QuickChoiceChip(
                                      label: '1 hr',
                                      selected: _manualStartsAt().difference(DateTime.now()).inMinutes > 35 &&
                                          _manualStartsAt().difference(DateTime.now()).inMinutes <= 65,
                                      onTap: () => _setManualTimeFromDateTime(DateTime.now().add(const Duration(hours: 1))),
                                    ),
                                    const SizedBox(width: 8),
                                    _QuickChoiceChip(
                                      label: 'Custom',
                                      selected: false,
                                      onTap: _editManualTime,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Place / Venue',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _showLocationPicker(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  isNearYou ? 'Near you' : manualLocation,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.expand_more, size: 14, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'People',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _QuickChoiceChip(
                              label: 'Limited',
                              selected: !_manualOpenGroup,
                              onTap: () => setState(() => _manualOpenGroup = false),
                            ),
                            const SizedBox(width: 8),
                            _QuickChoiceChip(
                              label: 'Open group',
                              selected: _manualOpenGroup,
                              onTap: () {
                                if (_manualCategory == SparkCategory.ride) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ride sparks require a seat count.'),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _manualOpenGroup = true);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_manualOpenGroup)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Anyone can join',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        else
                          _PeopleStepper(
                            value: _manualSpotsValue(),
                            onDecrease: () {
                              final next = (_manualSpotsValue() - 1).clamp(1, 20);
                              setState(() => _manualSpotsController.text = '$next');
                            },
                            onIncrease: () {
                              final next = (_manualSpotsValue() + 1).clamp(1, 20);
                              setState(() => _manualSpotsController.text = '$next');
                            },
                          ),
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _editManualNote,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.notes_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _manualNoteController.text.trim().isEmpty
                                        ? 'Add details (optional)'
                                        : _manualNoteController.text.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _previewExpanded = !_previewExpanded),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Preview',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                _previewExpanded ? Icons.expand_less : Icons.expand_more,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (!_previewExpanded)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '${manualPlan.title} • ${isNearYou ? "Near you" : manualLocation} • ${_previewRelativeTime(manualPlan.startsAt ?? DateTime.now())} • ${_manualOpenGroup ? "Open group" : "${_manualSpotsValue()} people"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        if (_previewExpanded)
                          _AutoPreviewCard(
                            plan: manualPlan,
                            selectedLocation: selectedLocation,
                            timeText: _previewTimeLabel(manualPlan.startsAt ?? DateTime.now()),
                            relativeTimeText: _previewRelativeTime(
                              manualPlan.startsAt ?? DateTime.now().add(const Duration(minutes: 1)),
                            ),
                            hasExplicitSpots: !_manualOpenGroup,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (ctaHint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    ctaHint,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _isManualMode ? const Color(0xFFDC2626) : AppColors.textSecondary,
                    ),
                  ),
                ),
              PrimaryButton(
                label: 'Create',
                backgroundColor: AppColors.accent,
                onPressed: () async {
                  if (validationMessage == null) {
                    await _createSpark();
                    return;
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(validationMessage),
                      backgroundColor: const Color(0xFFB91C1C),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _categoryAccentColor(SparkCategory cat) => switch (cat) {
        SparkCategory.sports => const Color(0xFF86EFAC),
        SparkCategory.study => const Color(0xFF93C5FD),
        SparkCategory.ride => const Color(0xFFC4B5FD),
        SparkCategory.events => const Color(0xFFFDBA74),
        SparkCategory.hangout => const Color(0xFFF9A8D4),
      };

  static IconData _categoryIcon(SparkCategory cat) => switch (cat) {
        SparkCategory.sports => Icons.directions_run_rounded,
        SparkCategory.study => Icons.auto_stories_rounded,
        SparkCategory.ride => Icons.drive_eta_rounded,
        SparkCategory.events => Icons.confirmation_number_outlined,
        SparkCategory.hangout => Icons.coffee_outlined,
      };

  void _setPlanText(String value) {
    _planController.text = value;
    _planController.selection = TextSelection.fromPosition(
      TextPosition(offset: _planController.text.length),
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _stopVoiceInput();
      return;
    }
    if (!_speechReady) {
      await _initSpeech();
      if (!_speechReady) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice input is not available on this device.')),
        );
        return;
      }
    }

    _lastVoiceTranscript = '';
    setState(() => _isListening = true);

    await _speechToText.listen(
      onResult: (result) {
        final spoken = result.recognizedWords.trim();
        if (spoken.isNotEmpty) {
          _lastVoiceTranscript = spoken;
          _setPlanText(spoken);
        }
        if (result.finalResult) {
          _stopVoiceInput();
          return;
        }
        _speechSilenceTimer?.cancel();
        _speechSilenceTimer = Timer(const Duration(seconds: 2), () {
          _stopVoiceInput();
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _stopVoiceInput() async {
    _speechSilenceTimer?.cancel();
    await _speechToText.stop();
    if (!mounted) return;
    final emptyCapture = _lastVoiceTranscript.trim().isEmpty;
    setState(() => _isListening = false);
    if (emptyCapture) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't catch that. Try again.")),
      );
    }
  }

  List<String> _smartSuggestions(String selectedLocation) {
    final hour = DateTime.now().hour;
    final near = selectedLocation;
    if (hour < 11) {
      return [
        'Interview prep in 2 hours near $near',
        'Chai now near $near',
      ];
    }
    if (hour < 17) {
      return [
        'Ride to office in 30 min from $near',
        'Study sprint in 1 hour near $near',
      ];
    }
    return [
      'Cricket at 6 near $near',
      'Coffee catch-up now near $near',
    ];
  }

  Future<void> _handleCreateTapped(_InferredPlan autoPlan, String? validationMessage) async {
    if (validationMessage == null) {
      await _createSpark();
      return;
    }

    if (_isManualMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationMessage),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
      return;
    }

    if (validationMessage.contains('Set seats for this ride spark')) {
      await _editAutoSpots(autoPlan);
      return;
    }

    if (validationMessage.toLowerCase().contains('future time') ||
        validationMessage.toLowerCase().contains('within 24')) {
      setState(() {
        _autoTimeOverride = DateTime.now().add(const Duration(minutes: 30));
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time auto-set to in 30 min. You can edit it in Preview.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(validationMessage)),
    );
  }

  _InferredPlan _effectiveAutoPlan() {
    final selectedLocation = ref.read(selectedLocationProvider);
    final input = _planController.text.trim();
    final lower = input.toLowerCase();
    final fallback = _inferPlan(
      input: input,
      selectedLocation: selectedLocation,
    );
    final hasFreshAi = _aiInferred != null &&
        _lastAiInput == input &&
        _lastAiLocation == selectedLocation;
    final plan = hasFreshAi ? _aiInferred! : fallback;
    final timeIntent = _timeIntentFromInput(lower);
    final deterministicTime = _inferStartsAt(lower, DateTime.now());
    DateTime? startsAt = _autoTimeOverride;
    if (startsAt == null) {
      if (timeIntent.kind == _TimeIntentKind.resolved && deterministicTime != null) {
        startsAt = deterministicTime;
      } else if (timeIntent.kind == _TimeIntentKind.ambiguous) {
        startsAt = _resolveAmbiguousTime(timeIntent);
      } else {
        startsAt = deterministicTime ?? plan.startsAt ?? DateTime.now().add(const Duration(minutes: 30));
      }
    }

    return plan.copyWith(
      title: _sanitizeSparkTitle(plan.title),
      startsAt: startsAt,
      locationName: (_autoLocationOverride?.trim().isNotEmpty ?? false)
          ? _autoLocationOverride!.trim()
          : plan.locationName,
      maxSpots: _autoSpotsOverride ?? plan.maxSpots,
      note: (_autoNoteOverride?.trim().isNotEmpty ?? false) ? _autoNoteOverride!.trim() : plan.note,
    );
  }

  _TimeIntent _timeIntentFromInput(String lower) {
    if (RegExp(r'in\s+\d{1,3}\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours)')
        .hasMatch(lower)) {
      return const _TimeIntent(kind: _TimeIntentKind.resolved);
    }

    final explicit = RegExp(r'\bat\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b').firstMatch(lower);
    if (explicit == null) return const _TimeIntent(kind: _TimeIntentKind.missing);

    final hour = int.tryParse(explicit.group(1) ?? '');
    final minute = int.tryParse(explicit.group(2) ?? '0') ?? 0;
    if (hour == null || hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      return const _TimeIntent(kind: _TimeIntentKind.missing);
    }
    final hasMeridiem = (explicit.group(3) ?? '').isNotEmpty;
    return _TimeIntent(
      kind: hasMeridiem ? _TimeIntentKind.resolved : _TimeIntentKind.ambiguous,
      hour: hour,
      minute: minute,
    );
  }

  DateTime _resolveAmbiguousTime(_TimeIntent intent) {
    final now = DateTime.now();
    final hour = intent.hour ?? 6;
    final minute = intent.minute ?? 0;
    final amHour = hour == 12 ? 0 : hour;
    final pmHour = hour == 12 ? 12 : hour + 12;

    DateTime nextAtHour(int hour24) {
      var candidate = DateTime(now.year, now.month, now.day, hour24, minute);
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    final amCandidate = nextAtHour(amHour);
    final pmCandidate = nextAtHour(pmHour);
    return amCandidate.isBefore(pmCandidate) ? amCandidate : pmCandidate;
  }

  _InferredPlan _inferPlan({
    required String input,
    required String selectedLocation,
  }) {
    final text = input.trim();
    final lower = text.toLowerCase();
    final now = DateTime.now();
    final category = _inferCategory(lower);
    final locationName = _inferLocationName(lower, selectedLocation);
    final startsAt = _inferStartsAt(lower, now);
    final spots = _inferSpots(lower, category);
    final title = _inferTitle(text, category);
    return _InferredPlan(
      title: title,
      category: category,
      locationName: locationName,
      startsAt: startsAt,
      maxSpots: spots,
      note: null,
      source: 'heuristic',
    );
  }

  void _scheduleAiParse() {
    _aiDebounce?.cancel();
    final input = _planController.text.trim();
    if (input.length < 3) {
      setState(() {
        _isAiParsing = false;
        _isAiUnavailable = false;
        _aiInferred = null;
      });
      return;
    }
    _aiDebounce = Timer(const Duration(milliseconds: 450), _runAiParse);
  }

  Future<void> _runAiParse() async {
    final input = _planController.text.trim();
    final selectedLocation = ref.read(selectedLocationProvider);
    if (input.length < 3) return;
    if (mounted) setState(() => _isAiParsing = true);
    try {
      final parsed = await ref.read(planParseApiRepositoryProvider).parsePlan(
            input: input,
            locationHint: selectedLocation,
          );
      if (!mounted) return;
      setState(() {
        _lastAiInput = input;
        _lastAiLocation = selectedLocation;
        _isAiUnavailable = false;
        _aiInferred = _InferredPlan(
          title: parsed.title,
          category: parsed.category,
          locationName: parsed.locationName,
          startsAt: parsed.startsAt,
          maxSpots: parsed.maxSpots,
          note: null,
          source: parsed.source,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiInferred = null;
        _isAiUnavailable = true;
      });
    } finally {
      if (mounted) setState(() => _isAiParsing = false);
    }
  }

  SparkCategory _inferCategory(String lower) {
    if (lower.contains('study') || lower.contains('dsa') || lower.contains('library')) {
      return SparkCategory.study;
    }
    if (lower.contains('ride') || lower.contains('airport') || lower.contains('cab')) {
      return SparkCategory.ride;
    }
    if (lower.contains('event') || lower.contains('show') || lower.contains('open mic')) {
      return SparkCategory.events;
    }
    if (lower.contains('coffee') || lower.contains('chai') || lower.contains('hangout')) {
      return SparkCategory.hangout;
    }
    return SparkCategory.sports;
  }

  String _inferLocationName(String lower, String fallbackLocation) {
    final nearMatch = RegExp(
      r'near\s+(.+?)(?=\s+(?:in\s+\d|at\s+\d|today|tonight|tomorrow)\b|$)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (nearMatch != null) {
      final raw = nearMatch.group(1)?.trim() ?? '';
      if (raw.isNotEmpty) {
        return raw
            .split(RegExp(r'\s+'))
            .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
      }
    }
    return fallbackLocation;
  }

  DateTime? _inferStartsAt(String lower, DateTime now) {
    final inMinutesMatch =
        RegExp(r'in\s+(\d{1,3})\s*(m|min|mins|minute|minutes)').firstMatch(lower);
    if (inMinutesMatch != null) {
      final mins = int.tryParse(inMinutesMatch.group(1) ?? '') ?? 30;
      return now.add(Duration(minutes: mins.clamp(1, 24 * 60)));
    }
    final inHoursMatch = RegExp(r'in\s+(\d{1,2})\s*(h|hr|hrs|hour|hours)').firstMatch(lower);
    if (inHoursMatch != null) {
      final hours = int.tryParse(inHoursMatch.group(1) ?? '') ?? 1;
      return now.add(Duration(hours: hours.clamp(1, 24)));
    }
    final explicitTime = RegExp(r'(?:at\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?').firstMatch(lower);
    if (explicitTime != null) {
      final meridiem = explicitTime.group(3);
      if (meridiem == null) return null;
      final rawHour = int.tryParse(explicitTime.group(1) ?? '');
      final rawMinute = int.tryParse(explicitTime.group(2) ?? '0') ?? 0;
      if (rawHour == null || rawHour < 1 || rawHour > 12) return null;
      final hour24 = meridiem == 'am'
          ? (rawHour == 12 ? 0 : rawHour)
          : (rawHour == 12 ? 12 : rawHour + 12);
      var candidate = DateTime(now.year, now.month, now.day, hour24, rawMinute);
      if (candidate.isBefore(now.add(const Duration(minutes: 1)))) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }
    return null;
  }

  int _inferSpots(String lower, SparkCategory category) {
    final spotsMatch = RegExp(r'(\d{1,2})\s*(spots|spot|people|ppl)').firstMatch(lower);
    if (spotsMatch != null) {
      final count = int.tryParse(spotsMatch.group(1) ?? '');
      if (count != null) return count.clamp(1, 20);
    }
    return switch (category) {
      SparkCategory.ride => 2,
      SparkCategory.study => 4,
      SparkCategory.events => 6,
      SparkCategory.hangout => 4,
      SparkCategory.sports => 5,
    };
  }

  String _inferTitle(String input, SparkCategory category) {
    final cleaned = _sanitizeSparkTitle(input);
    if (cleaned.isNotEmpty) {
      final text = cleaned[0].toUpperCase() + cleaned.substring(1);
      return text.length > 64 ? '${text.substring(0, 64)}…' : text;
    }
    return switch (category) {
      SparkCategory.sports => 'Quick sports plan',
      SparkCategory.study => 'Study session',
      SparkCategory.ride => 'Ride share',
      SparkCategory.events => 'Nearby event',
      SparkCategory.hangout => 'Hangout plan',
    };
  }

  String _sanitizeSparkTitle(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return text;

    // Remove obvious timing fragments from title intent.
    text = text.replaceAll(
      RegExp(r'\b(in\s+\d{1,3}\s*(?:m|min|mins|minute|minutes|h|hr|hrs|hour|hours))\b', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\b(at\s*\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b', caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\b(today|tonight|tomorrow|now)\b', caseSensitive: false),
      '',
    );

    // Remove location hint from title ("near ...").
    text = text.replaceAll(
      RegExp(r'\bnear\s+.+$', caseSensitive: false),
      '',
    );

    // Normalize spacing/punctuation left after cleanup.
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    text = text.replaceAll(RegExp(r'[\s,.;:-]+$'), '').trim();

    if (text.isEmpty) return 'Quick plan';
    return text;
  }

  String? _autoValidationMessage(_InferredPlan plan) {
    if (_planController.text.trim().isEmpty) return 'Type one line to create spark';
    if (plan.category == SparkCategory.ride &&
        _autoSpotsOverride == null &&
        !_hasSpotsIntent(_planController.text.toLowerCase())) {
      return 'Set seats for this ride spark.';
    }
    final now = DateTime.now();
    if (plan.startsAt!.isBefore(now.subtract(const Duration(minutes: 1)))) {
      return 'Pick a future time';
    }
    if (plan.startsAt!.difference(now) > const Duration(hours: 24)) {
      return 'Spark time must be within 24 hours';
    }
    return null;
  }

  bool _hasSpotsIntent(String lower) {
    return RegExp(r'(\d{1,2})\s*(spot|spots|seat|seats|people|ppl)').hasMatch(lower);
  }

  String? _manualValidationMessage() {
    if (_manualTitleController.text.trim().isEmpty) return 'Title is required';
    final location = _manualLocationController.text.trim().isEmpty
        ? ref.read(selectedLocationProvider)
        : _manualLocationController.text.trim();
    if (location.isEmpty) return 'Place / Venue is required';
    final startsAt = _manualStartsAt();
    final now = DateTime.now();
    if (startsAt.isBefore(now.subtract(const Duration(minutes: 1)))) {
      return 'Pick a future time';
    }
    if (startsAt.difference(now) > const Duration(hours: 24)) {
      return 'Spark time must be within 24 hours';
    }
    return null;
  }

  Future<void> _createSpark() async {
    final draft = _isManualMode ? _manualDraft() : _effectiveAutoPlan();
    Spark createdSpark;
    try {
      createdSpark = await ref.read(sparkDataControllerProvider).createSpark(
            category: draft.category,
            title: draft.title,
            note: draft.note,
            locationName: draft.locationName,
            startsAt: draft.startsAt ?? DateTime.now().add(const Duration(minutes: 30)),
            maxSpots: draft.maxSpots,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_userFacingSparkError(e)),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
      return;
    }

    ref.read(bottomTabProvider.notifier).state = 0;
    if (!mounted) return;
    await showInviteFriendsBottomSheet(
      context: context,
      spark: createdSpark,
      source: 'post_create',
      onViewSpark: () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SparkDetailScreen(spark: createdSpark)),
        );
      },
    );
  }

  String _userFacingSparkError(Object error) {
    String raw = error.toString();

    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final serverMsg = data['message'] ?? data['error'] ?? data['detail'];
        if (serverMsg is String && serverMsg.trim().isNotEmpty) {
          raw = serverMsg.trim();
        }
      }
    }

    final lower = raw.toLowerCase();

    if (lower.contains('respectful') ||
        lower.contains('offensive') ||
        lower.contains('abusive') ||
        lower.contains('neutral') ||
        lower.contains('religious') ||
        lower.contains('hate') ||
        lower.contains('unsafe') ||
        lower.contains('blocked')) {
      return 'Please keep spark text respectful and neutral.';
    }

    if (lower.contains('note') && (lower.contains('max') || lower.contains('word'))) {
      return 'Please keep your note concise (up to 15 words).';
    }

    if (lower.contains('24') || lower.contains('within next 24')) {
      return 'Spark time must be within the next 24 hours.';
    }

    if (lower.contains('time') && lower.contains('required')) {
      return 'Please add a clear time like “6 PM” or “in 30 min”.';
    }

    if (lower.contains('location')) {
      return 'Please choose a valid place / venue before creating the spark.';
    }

    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Connection issue. Please try again in a moment.';
    }

    if (error is DioException && (error.response?.statusCode ?? 0) >= 500) {
      return 'Server is busy right now. Please try again shortly.';
    }

    return 'Could not create spark right now. Please try again.';
  }

  void _hydrateManualFromAuto(_InferredPlan plan) {
    _manualTitleController.text = plan.title;
    _manualLocationController.text = plan.locationName;
    _manualSpotsController.text = '${plan.maxSpots}';
    _manualNoteController.text = plan.note ?? '';
    _manualCategory = plan.category;
    final ts = plan.startsAt ?? DateTime.now().add(const Duration(minutes: 30));
    final ambiguousClock = _extractAmbiguousClock(_planController.text.toLowerCase());

    _manualSelectedDate = DateTime(ts.year, ts.month, ts.day);
    if (plan.startsAt == null && ambiguousClock != null) {
      _manualHour = ambiguousClock.$1;
      _manualMinute = ambiguousClock.$2;
      _manualPeriod = 'PM';
    } else {
      _manualHour = _to12Hour(ts.hour);
      _manualMinute = ts.minute;
      _manualPeriod = ts.hour >= 12 ? 'PM' : 'AM';
    }
  }

  (int, int)? _extractAmbiguousClock(String lower) {
    final explicit = RegExp(r'\bat\s*(\d{1,2})(?::(\d{2}))?\s*(?!am\b|pm\b)', caseSensitive: false)
        .firstMatch(lower);
    if (explicit == null) return null;
    final hour = int.tryParse(explicit.group(1) ?? '');
    final minute = int.tryParse(explicit.group(2) ?? '0') ?? 0;
    if (hour == null || hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      return null;
    }
    return (hour, minute);
  }

  _InferredPlan _manualDraft() {
    final fallbackLocation = ref.read(selectedLocationProvider);
    return _InferredPlan(
      title: _manualTitleController.text.trim(),
      category: _manualCategory,
      locationName: _manualLocationController.text.trim().isEmpty
          ? fallbackLocation
          : _manualLocationController.text.trim(),
      startsAt: _manualStartsAt(),
      maxSpots: _manualOpenGroup ? 20 : _manualSpotsValue(),
      note: _manualNoteController.text.trim().isEmpty
          ? null
          : _manualNoteController.text.trim(),
      source: 'manual',
    );
  }

  DateTime _manualStartsAt() {
    final hour24 = _manualPeriod == 'AM'
        ? (_manualHour == 12 ? 0 : _manualHour)
        : (_manualHour == 12 ? 12 : _manualHour + 12);
    return DateTime(
      _manualSelectedDate.year,
      _manualSelectedDate.month,
      _manualSelectedDate.day,
      hour24,
      _manualMinute,
    );
  }

  Future<void> _pickManualDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _manualSelectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _manualSelectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  int _manualSpotsValue() {
    final parsed = int.tryParse(_manualSpotsController.text.trim());
    if (parsed == null || parsed < 1) return 1;
    return parsed.clamp(1, 20);
  }

  int _to12Hour(int hour24) {
    if (hour24 == 0 || hour24 == 12) return 12;
    return hour24 > 12 ? hour24 - 12 : hour24;
  }

  String _previewTimeLabel(DateTime value) {
    final now = DateTime.now();
    final diff = value.difference(now);
    if (diff.inMinutes > 0 && diff.inMinutes <= 60) {
      return 'In ${diff.inMinutes} min';
    }
    final isToday = DateUtils.isSameDay(now, value);
    final dayLabel = isToday ? 'Today' : 'Tomorrow';
    final hour = (value.hour % 12 == 0) ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$dayLabel $hour:$minute $period';
  }

  String _previewRelativeTime(DateTime value) {
    final diff = value.difference(DateTime.now());
    if (diff.inMinutes <= 1) return 'Starting now';
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes} min';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (mins == 0) return 'In $hours hr';
    return 'In ${hours}h ${mins}m';
  }

  Future<void> _editAutoTime() async {
    if (!mounted) return;
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flash_on_outlined),
              title: const Text('Now'),
              onTap: () => Navigator.of(context).pop('now'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('In 30 min'),
              onTap: () => Navigator.of(context).pop('30'),
            ),
            ListTile(
              leading: const Icon(Icons.wb_twilight_outlined),
              title: const Text('This evening (6:00 PM)'),
              onTap: () => Navigator.of(context).pop('evening'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Pick custom time'),
              onTap: () => Navigator.of(context).pop('custom'),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;
    final now = DateTime.now();
    if (selection == 'now') {
      setState(() => _autoTimeOverride = now.add(const Duration(minutes: 2)));
      return;
    }
    if (selection == '30') {
      setState(() => _autoTimeOverride = now.add(const Duration(minutes: 30)));
      return;
    }
    if (selection == 'evening') {
      var evening = DateTime(now.year, now.month, now.day, 18, 0);
      if (evening.isBefore(now)) evening = evening.add(const Duration(days: 1));
      setState(() => _autoTimeOverride = evening);
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    var candidate = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    setState(() => _autoTimeOverride = candidate);
  }

  Future<void> _editAutoLocation() async {
    final saved = ref.read(savedLocationsProvider);
    final recent = ref.read(recentLocationsProvider);
    final catalog = ref.read(locationCatalogProvider);
    final selected = ref.read(selectedLocationProvider);
    final placesService = ref.read(placesAutocompleteServiceProvider);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => LocationPickerSheet(
        title: 'Set place / venue',
        selectedLocation: _autoLocationOverride ?? selected,
        savedLocations: saved,
        recentLocations: recent,
        catalogLocations: catalog,
        placesService: placesService,
        onSelect: (place) {
          setState(() => _autoLocationOverride = place);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _editAutoSpots(_InferredPlan plan) async {
    final controller = TextEditingController(text: '${_autoSpotsOverride ?? plan.maxSpots}');
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(plan.category == SparkCategory.ride ? 'Set seats' : 'How many people?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: plan.category == SparkCategory.ride
                ? 'Enter seats'
                : 'Enter number of people',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        buttonPadding: EdgeInsets.zero,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null) return;
                Navigator.of(context).pop(parsed.clamp(1, 20));
              },
              child: const Text('Save'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _autoSpotsOverride = result);
  }

  Future<void> _editAutoNote() async {
    final controller = TextEditingController(text: _autoNoteOverride ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add details'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 2,
          inputFormatters: [_WordLimitFormatter(maxWords: 15)],
          decoration: const InputDecoration(hintText: 'Optional note (max 15 words)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _autoNoteOverride = result.isEmpty ? null : result);
  }

  Future<void> _editManualTime() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flash_on_outlined),
              title: const Text('Now'),
              onTap: () => Navigator.of(context).pop('now'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('In 30 min'),
              onTap: () => Navigator.of(context).pop('30'),
            ),
            ListTile(
              leading: const Icon(Icons.wb_twilight_outlined),
              title: const Text('This evening (6:00 PM)'),
              onTap: () => Navigator.of(context).pop('evening'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Pick custom time'),
              onTap: () => Navigator.of(context).pop('custom'),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;
    final now = DateTime.now();
    if (selection == 'now') {
      _setManualTimeFromDateTime(now.add(const Duration(minutes: 2)));
      return;
    }
    if (selection == '30') {
      _setManualTimeFromDateTime(now.add(const Duration(minutes: 30)));
      return;
    }
    if (selection == 'evening') {
      var evening = DateTime(now.year, now.month, now.day, 18, 0);
      if (evening.isBefore(now)) evening = evening.add(const Duration(days: 1));
      _setManualTimeFromDateTime(evening);
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    var candidate = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    _setManualTimeFromDateTime(candidate);
  }

  void _setManualTimeFromDateTime(DateTime ts) {
    setState(() {
      _manualSelectedDate = DateTime(ts.year, ts.month, ts.day);
      _manualHour = _to12Hour(ts.hour);
      _manualMinute = ts.minute;
      _manualPeriod = ts.hour >= 12 ? 'PM' : 'AM';
    });
  }

  Future<void> _editManualSpots() async {
    final controller = TextEditingController(text: _manualSpotsController.text.trim().isEmpty ? '3' : _manualSpotsController.text.trim());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_manualCategory == SparkCategory.ride ? 'How many seats?' : 'How many people?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: _manualCategory == SparkCategory.ride ? 'Enter seats' : 'Enter number of people',
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        buttonPadding: EdgeInsets.zero,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null) return;
                Navigator.of(context).pop(parsed.clamp(1, 20));
              },
              child: const Text('Save'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _manualSpotsController.text = '$result');
  }

  Future<void> _editManualNote() async {
    final controller = TextEditingController(text: _manualNoteController.text.trim());
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add details'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 2,
          inputFormatters: [_WordLimitFormatter(maxWords: 15)],
          decoration: const InputDecoration(hintText: 'Optional note (max 15 words)'),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        buttonPadding: EdgeInsets.zero,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _manualNoteController.text = result);
  }

  void _showLocationPicker(BuildContext context) {
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
        title: 'Post in area',
        selectedLocation: selected,
        savedLocations: saved,
        recentLocations: recent,
        catalogLocations: catalog,
        placesService: placesService,
        onSelect: (place) {
          ref.read(selectedLocationProvider.notifier).state = place;
          if (_isManualMode) {
            _manualLocationController.text = place;
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.manual, required this.onChanged});

  final bool manual;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modePill(
            label: 'Auto',
            selected: !manual,
            onTap: () => onChanged(false),
          ),
          _modePill(
            label: 'Manual',
            selected: manual,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _modePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AutoPreviewCard extends StatelessWidget {
  const _AutoPreviewCard({
    required this.plan,
    required this.selectedLocation,
    required this.timeText,
    required this.relativeTimeText,
    required this.hasExplicitSpots,
  });

  final _InferredPlan plan;
  final String selectedLocation;
  final String timeText;
  final String? relativeTimeText;
  final bool hasExplicitSpots;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(plan.category.icon, size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ReadOnlyMetaChip(
            icon: Icons.place_outlined,
            value: plan.locationName.trim().toLowerCase() == selectedLocation.trim().toLowerCase()
                ? '${plan.locationName} (near you)'
                : plan.locationName,
          ),
          const SizedBox(height: 6),
          _ReadOnlyMetaChip(
            icon: Icons.schedule_outlined,
            value: relativeTimeText == null ? timeText : '$relativeTimeText • $timeText',
          ),
          const SizedBox(height: 6),
          _ReadOnlyMetaChip(
            icon: Icons.group_outlined,
            value: plan.category == SparkCategory.ride
                ? '${plan.maxSpots} seats'
                : (hasExplicitSpots ? '${plan.maxSpots} people' : 'Open group'),
          ),
        ],
      ),
    );
  }
}

class _ManualForm extends StatelessWidget {
  const _ManualForm({
    required this.titleController,
    required this.locationText,
    required this.spotsController,
    required this.noteController,
    required this.selectedDate,
    required this.hour,
    required this.minute,
    required this.period,
    required this.category,
    required this.onPickLocation,
    required this.onPickDate,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onPeriodChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController titleController;
  final String locationText;
  final TextEditingController spotsController;
  final TextEditingController noteController;
  final DateTime selectedDate;
  final int hour;
  final int minute;
  final String period;
  final SparkCategory category;
  final VoidCallback onPickLocation;
  final VoidCallback onPickDate;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<SparkCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = DateUtils.isSameDay(selectedDate, today);
    final dateLabel = isToday ? 'Today' : 'Tomorrow';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledField(
          label: 'Title',
          child: TextField(
            controller: titleController,
            decoration: const InputDecoration(hintText: 'Cricket at 6 near Central Park'),
          ),
        ),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Place / Venue',
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPickLocation,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: SparkCategory.values
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.label),
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      selected: c == category,
                      onSelected: (_) => onCategoryChanged(c),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            if (compact) {
              return Column(
                children: [
                  _ManualDateField(
                    dateLabel: dateLabel,
                    onTap: onPickDate,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SelectField<int>(
                          value: hour,
                          items: List.generate(12, (i) => i + 1),
                          labelBuilder: (v) => v.toString(),
                          onChanged: onHourChanged,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _SelectField<int>(
                          value: minute,
                          items: List.generate(60, (i) => i),
                          labelBuilder: (v) => v.toString().padLeft(2, '0'),
                          onChanged: onMinuteChanged,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _SelectField<String>(
                          value: period,
                          items: const ['AM', 'PM'],
                          labelBuilder: (v) => v,
                          onChanged: onPeriodChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _ManualDateField(
                    dateLabel: dateLabel,
                    onTap: onPickDate,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _SelectField<int>(
                    value: hour,
                    items: List.generate(12, (i) => i + 1),
                    labelBuilder: (v) => v.toString(),
                    onChanged: onHourChanged,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _SelectField<int>(
                    value: minute,
                    items: List.generate(60, (i) => i),
                    labelBuilder: (v) => v.toString().padLeft(2, '0'),
                    onChanged: onMinuteChanged,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _SelectField<String>(
                    value: period,
                    items: const ['AM', 'PM'],
                    labelBuilder: (v) => v,
                    onChanged: onPeriodChanged,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Spots',
          child: SizedBox(
            width: 90,
            child: TextField(
              controller: spotsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'Note (optional)',
          child: TextField(
            controller: noteController,
            minLines: 1,
            maxLines: 1,
            inputFormatters: [_WordLimitFormatter(maxWords: 15)],
            decoration: const InputDecoration(
              hintText: 'e.g. Bring your own bat and reach Gate 2',
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ManualDateField extends StatelessWidget {
  const _ManualDateField({
    required this.dateLabel,
    required this.onTap,
  });

  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectField<T> extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more, size: 16),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  labelBuilder(item),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue == null) return;
          onChanged(newValue);
        },
      ),
    );
  }
}

class _CreateScreenHeader extends StatelessWidget {
  const _CreateScreenHeader({required this.category});
  final SparkCategory category;

  static Color _accentColor(SparkCategory cat) => switch (cat) {
        SparkCategory.sports => const Color(0xFF86EFAC),
        SparkCategory.study => const Color(0xFF93C5FD),
        SparkCategory.ride => const Color(0xFFC4B5FD),
        SparkCategory.events => const Color(0xFFFDBA74),
        SparkCategory.hangout => const Color(0xFFF9A8D4),
      };

  static IconData _icon(SparkCategory cat) => switch (cat) {
        SparkCategory.sports => Icons.directions_run_rounded,
        SparkCategory.study => Icons.auto_stories_rounded,
        SparkCategory.ride => Icons.drive_eta_rounded,
        SparkCategory.events => Icons.confirmation_number_outlined,
        SparkCategory.hangout => Icons.coffee_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(category);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What's your plan?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Plan something tiny, nearby, right now.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _icon(category),
              key: ValueKey(category),
              color: accent == const Color(0xFF86EFAC)
                  ? const Color(0xFF15803D)
                  : accent == const Color(0xFF93C5FD)
                      ? const Color(0xFF1D4ED8)
                      : accent == const Color(0xFFC4B5FD)
                          ? const Color(0xFF6D28D9)
                          : accent == const Color(0xFFFDBA74)
                              ? const Color(0xFFB45309)
                              : const Color(0xFFBE185D),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.accentColor});

  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (accentColor != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                color: accentColor,
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChoiceChip extends StatelessWidget {
  const _QuickChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PeopleStepper extends StatelessWidget {
  const _PeopleStepper({
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onDecrease,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove, size: 16),
            color: AppColors.textSecondary,
          ),
          Expanded(
            child: Text(
              '$value people',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add, size: 16),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyMetaChip extends StatelessWidget {
  const _ReadOnlyMetaChip({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _MicPulseDot extends StatefulWidget {
  const _MicPulseDot();

  @override
  State<_MicPulseDot> createState() => _MicPulseDotState();
}

class _MicPulseDotState extends State<_MicPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final size = 8 + (t * 4);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.5 + (t * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _InferredPlan {
  const _InferredPlan({
    required this.title,
    required this.category,
    required this.locationName,
    required this.startsAt,
    required this.maxSpots,
    required this.note,
    required this.source,
  });

  final String title;
  final SparkCategory category;
  final String locationName;
  final DateTime? startsAt;
  final int maxSpots;
  final String? note;
  final String source;

  _InferredPlan copyWith({
    String? title,
    SparkCategory? category,
    String? locationName,
    DateTime? startsAt,
    int? maxSpots,
    String? note,
    String? source,
    bool clearStartsAt = false,
  }) {
    return _InferredPlan(
      title: title ?? this.title,
      category: category ?? this.category,
      locationName: locationName ?? this.locationName,
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      maxSpots: maxSpots ?? this.maxSpots,
      note: note ?? this.note,
      source: source ?? this.source,
    );
  }
}

enum _TimeIntentKind { missing, ambiguous, resolved }

class _TimeIntent {
  const _TimeIntent({
    required this.kind,
    this.hour,
    this.minute,
  });

  final _TimeIntentKind kind;
  final int? hour;
  final int? minute;
}

class _WordLimitFormatter extends TextInputFormatter {
  _WordLimitFormatter({required this.maxWords});

  final int maxWords;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final trimmed = newValue.text.trim();
    if (trimmed.isEmpty) return newValue;
    final count = trimmed.split(RegExp(r'\s+')).length;
    if (count <= maxWords) return newValue;
    return oldValue;
  }
}
