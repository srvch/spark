import 'dart:async';
// ignore_for_file: unused_element, unused_field, prefer_final_fields

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../../shared/widgets/invite_friends_sheet.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../social/presentation/controllers/social_controller.dart';
import '../../domain/spark.dart';
import '../controllers/spark_controller.dart';
import '../widgets/location_picker_sheet.dart';
import 'spark_detail_screen.dart';

const _kActionBlue = Color(0xFF355588);
const _kActionBlueDeep = Color(0xFF294975);

class CreateSparkScreen extends ConsumerStatefulWidget {
  const CreateSparkScreen({super.key, this.prefill});

  /// When set, pre-fills the manual form with this spark's data ("Post again").
  final Spark? prefill;

  @override
  ConsumerState<CreateSparkScreen> createState() => _CreateSparkScreenState();
}

class _CreateSparkScreenState extends ConsumerState<CreateSparkScreen> {
  final TextEditingController _planController = TextEditingController(
    text: '',
  );
  final TextEditingController _manualTitleController = TextEditingController();
  final TextEditingController _manualLocationController =
      TextEditingController();
  final TextEditingController _manualSpotsController = TextEditingController(
    text: '2',
  );
  final TextEditingController _manualNoteController = TextEditingController();

  Timer? _aiDebounce;
  _InferredPlan? _aiInferred;
  bool _isAiParsing = false;
  bool _isAiUnavailable = false;
  String _lastAiInput = '';
  String _lastAiLocation = '';
  String? _lastSeenSelectedLocation;
  String _lastPlanText = '';

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
  SparkVisibility _manualVisibility = SparkVisibility.publicSpark;
  final Set<String> _selectedCircleIds = <String>{};
  final Set<String> _selectedInviteUserIds = <String>{};
  final Set<String> _manualInvitePhones = <String>{};
  bool _manualOpenGroup = false;
  bool _previewExpanded = false;
  bool _isCreatingSpark = false;
  String? _guestPhoneInlineError;

  // Recurrence
  bool _isRecurring = false;
  String _recurrenceType = 'WEEKLY'; // DAILY or WEEKLY
  int _recurrenceDayOfWeek = 1; // 1=Mon … 7=Sun
  DateTime? _recurrenceEndDate;
  String? _prefillLocationToApply;

  bool get _isEditMode => widget.prefill != null;

  @override
  void initState() {
    super.initState();
    _isRecurring = false;
    _recurrenceType = 'WEEKLY';
    _recurrenceEndDate = null;
    final now = DateTime.now().add(const Duration(minutes: 30));
    _manualSelectedDate = DateTime(now.year, now.month, now.day);
    _manualHour = _to12Hour(now.hour);
    _manualMinute = now.minute;
    _manualPeriod = now.hour >= 12 ? 'PM' : 'AM';
    _planController.addListener(_onPlanChanged);
    // Pre-fill if "Post again" was triggered
    final prefill = widget.prefill;
    if (prefill != null) {
      _isManualMode = true;
      _manualTitleController.text = prefill.title;
      _manualLocationController.text = prefill.location;
      _manualNoteController.text = prefill.note ?? '';
      _manualCategory = prefill.category;
      _manualVisibility =
          prefill.visibility == SparkVisibility.publicSpark
              ? SparkVisibility.publicSpark
              : SparkVisibility.invite;
      _isRecurring = prefill.recurrenceType != null;
      _recurrenceType =
          (prefill.recurrenceType ?? 'WEEKLY').toUpperCase() == 'DAILY'
              ? 'DAILY'
              : 'WEEKLY';
      _manualOpenGroup = prefill.maxSpots == 0;
      if (prefill.maxSpots > 0) {
        _manualSpotsController.text = prefill.maxSpots.toString();
      }
      _prefillLocationToApply = prefill.location;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_prefillLocationToApply != null) {
        ref.read(selectedLocationProvider.notifier).state =
            _prefillLocationToApply!;
      }
      unawaited(ref.read(socialControllerProvider).refreshAll());
    });
  }

  @override
  void dispose() {
    _aiDebounce?.cancel();
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
    final dynamicSuggestions = _smartSuggestions(selectedLocation);
    final manualLocation =
        _manualLocationController.text.trim().isEmpty
            ? selectedLocation
            : _manualLocationController.text.trim();
    final isNearYou = _isNearYouLocationLabel(manualLocation);
    final startsAt = _manualStartsAt();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CreateScreenHeader(
              category: _manualCategory,
              onBackTap: () => backOrGoDiscover(context, ref),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 180),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─────────── WHAT ───────────
                    _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel(
                            icon: Icons.bolt_rounded,
                            text: 'What\'s the spark?',
                          ),
                          const SizedBox(height: 12),
                          _TitleField(
                            controller: _manualTitleController,
                            onChanged: () => setState(() {}),
                          ),
                          if (_manualTitleController.text.trim().isEmpty &&
                              dynamicSuggestions.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: dynamicSuggestions
                                  .take(2)
                                  .map(
                                    (label) => _SuggestionChip(
                                      label: label,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _manualTitleController.text = label;
                                        _manualTitleController.selection =
                                            TextSelection.fromPosition(
                                              TextPosition(
                                                offset: _manualTitleController
                                                    .text.length,
                                              ),
                                            );
                                        setState(() {});
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 18),
                          const _SectionLabel(
                            icon: Icons.category_rounded,
                            text: 'Category',
                          ),
                          const SizedBox(height: 10),
                          _CategoryRail(
                            selected: _manualCategory,
                            onChanged: (c) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _manualCategory = c;
                                if (c == SparkCategory.ride) {
                                  _manualOpenGroup = false;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ─────────── WHEN ───────────
                    _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel(
                            icon: Icons.schedule_rounded,
                            text: 'When',
                          ),
                          const SizedBox(height: 12),
                          _TimeChips(
                            startsAt: startsAt,
                            onPickQuick: (dt) {
                              HapticFeedback.selectionClick();
                              _setManualTimeFromDateTime(dt);
                            },
                            onPickCustom: _editManualTime,
                          ),
                          const SizedBox(height: 12),
                          _TimeConfirmation(
                            label: _previewTimeLabel(startsAt),
                            relative: _previewRelativeTime(startsAt),
                          ),
                          const SizedBox(height: 14),
                          _RecurrenceSection(
                            isRecurring: _isRecurring,
                            recurrenceType: _recurrenceType,
                            recurrenceDayOfWeek: _recurrenceDayOfWeek,
                            recurrenceEndDate: _recurrenceEndDate,
                            onToggle: (v) =>
                                setState(() => _isRecurring = v),
                            onTypeChanged: (t) =>
                                setState(() => _recurrenceType = t),
                            onDayChanged: (d) =>
                                setState(() => _recurrenceDayOfWeek = d),
                            onEndDateChanged: (dt) =>
                                setState(() => _recurrenceEndDate = dt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ─────────── WHERE ───────────
                    _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel(
                            icon: Icons.place_rounded,
                            text: 'Where',
                          ),
                          const SizedBox(height: 12),
                          _PlaceTile(
                            location: isNearYou ? 'Near you' : manualLocation,
                            isNearYou: isNearYou,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showLocationPicker(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ─────────── WHO ───────────
                    _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel(
                            icon: Icons.people_alt_rounded,
                            text: 'Who can join',
                          ),
                          const SizedBox(height: 12),
                          _VisibilitySegmented(
                            isPublic: _manualVisibility ==
                                SparkVisibility.publicSpark,
                            onChanged: (isPublic) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (isPublic) {
                                  _manualVisibility =
                                      SparkVisibility.publicSpark;
                                  _selectedCircleIds.clear();
                                  _selectedInviteUserIds.clear();
                                  _manualInvitePhones.clear();
                                  _guestPhoneInlineError = null;
                                } else {
                                  _manualVisibility = SparkVisibility.invite;
                                  _selectedCircleIds.clear();
                                  _guestPhoneInlineError = null;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) => SizeTransition(
                              sizeFactor: anim,
                              axisAlignment: -1,
                              child: FadeTransition(
                                opacity: anim,
                                child: child,
                              ),
                            ),
                            child: _manualVisibility == SparkVisibility.invite
                                ? Column(
                                    key: const ValueKey('invite-block'),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'Hidden from Discover. Share via link or invite by phone.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ),
                                      _AudiencePickerRow(
                                        title: 'Guest phone invites',
                                        cta: 'Add phone',
                                        value: _manualInvitePhones.isEmpty
                                            ? 'No guest phones added'
                                            : '${_manualInvitePhones.length} added',
                                        onTap: _addGuestPhoneInvite,
                                      ),
                                      if (_guestPhoneInlineError != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          _guestPhoneInlineError!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.dangerText,
                                          ),
                                        ),
                                      ],
                                      if (_manualInvitePhones.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _manualInvitePhones
                                              .map(
                                                (phone) => _RemovablePill(
                                                  text: phone,
                                                  onRemove: () => setState(() {
                                                    _manualInvitePhones
                                                        .remove(phone);
                                                    if (_manualInvitePhones
                                                        .isNotEmpty) {
                                                      _guestPhoneInlineError =
                                                          null;
                                                    }
                                                  }),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ],
                                    ],
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('public-empty'),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          _GroupSizeBlock(
                            isOpenGroup: _manualOpenGroup,
                            spots: _manualSpotsValue(),
                            isRideCategory:
                                _manualCategory == SparkCategory.ride,
                            onSetOpen: (open) {
                              if (open &&
                                  _manualCategory == SparkCategory.ride) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ride sparks require a seat count.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              HapticFeedback.selectionClick();
                              setState(() => _manualOpenGroup = open);
                            },
                            onIncrease: () {
                              HapticFeedback.lightImpact();
                              final next = (_manualSpotsValue() + 1)
                                  .clamp(1, 20);
                              setState(() =>
                                  _manualSpotsController.text = '$next');
                            },
                            onDecrease: () {
                              HapticFeedback.lightImpact();
                              final next = (_manualSpotsValue() - 1)
                                  .clamp(1, 20);
                              setState(() =>
                                  _manualSpotsController.text = '$next');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ─────────── EXTRAS ───────────
                    _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel(
                            icon: Icons.tune_rounded,
                            text: 'Extras',
                          ),
                          const SizedBox(height: 12),
                          _NoteTile(
                            note: _manualNoteController.text.trim(),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _editManualNote();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _StickyCreateBar(
        title: manualPlan.title.isEmpty ? 'Your spark' : manualPlan.title,
        location: isNearYou ? 'Near you' : manualLocation,
        timeRelative: _previewRelativeTime(startsAt),
        spotsLabel: _manualOpenGroup
            ? 'Open group'
            : (_manualCategory == SparkCategory.ride
                ? '${_manualSpotsValue()} ${_manualSpotsValue() == 1 ? "seat" : "seats"}'
                : '${_manualSpotsValue()} ${_manualSpotsValue() == 1 ? "spot" : "spots"}'),
        category: _manualCategory,
        ctaLabel: _isCreatingSpark
            ? (_isEditMode ? 'Saving…' : 'Creating…')
            : (_isEditMode ? 'Save changes' : 'Create spark'),
        loading: _isCreatingSpark,
        onPressed: _isCreatingSpark
            ? null
            : () async {
                final message = _manualValidationMessage();
                if (message == null) {
                  await _createSpark();
                  return;
                }
                if (_manualVisibility == SparkVisibility.invite &&
                    _manualInvitePhones.isEmpty) {
                  setState(() {
                    _guestPhoneInlineError =
                        'Add at least one valid phone number';
                  });
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: AppColors.danger,
                  ),
                );
              },
      ),
    );
  }

  static Color _categoryAccentColor(SparkCategory cat) => cat.accentColor;

  static String _categoryEmoji(SparkCategory cat) => switch (cat) {
    SparkCategory.sports  => '⚽',
    SparkCategory.study   => '📚',
    SparkCategory.ride    => '🛵',
    SparkCategory.events  => '🎉',
    SparkCategory.hangout => '☕',
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

  List<String> _smartSuggestions(String selectedLocation) {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return [
        'Morning run',
        'Chai catch-up',
      ];
    }
    if (hour < 17) {
      return [
        'Lunch hangout',
        'Study sprint',
      ];
    }
    return [
      'Cricket at 6',
      'Evening walk',
    ];
  }

  Future<void> _pickCircles() async {
    final options = _circleOptionsFromState();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No groups found. Create a group first.')),
      );
      return;
    }
    final selected = await _showAudiencePicker(
      title: 'Select groups',
      options: options,
      initialSelection: _selectedCircleIds,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedCircleIds
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _pickInviteUsers() async {
    final options = _inviteUserOptionsFromState();
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No friends found. Add friends first.')),
      );
      return;
    }
    final selected = await _showAudiencePicker(
      title: 'Invite users',
      options: options,
      initialSelection: _selectedInviteUserIds,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedInviteUserIds
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _addGuestPhoneInvite() async {
    final controller = TextEditingController();
    String? dialogError;
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: const Text('Add guest phone'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'e.g. +919876543210',
                        errorText: dialogError,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Format: country code + number',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kActionBlue,
                    ),
                    onPressed: () {
                      final normalized = _normalizePhone(controller.text);
                      if (normalized == null) {
                        setDialogState(() {
                          dialogError = 'Enter a valid phone number';
                        });
                        return;
                      }
                      Navigator.of(context).pop(normalized);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
        );
      },
    );
    if (!mounted || value == null || value.isEmpty) return;
    setState(() {
      _manualInvitePhones.add(value);
      _guestPhoneInlineError = null;
    });
  }

  String? _normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final keep = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    final digits = keep.replaceAll('+', '');
    if (digits.length < 8 || digits.length > 15) return null;
    if (keep.startsWith('+')) return '+$digits';
    return digits;
  }

  List<_AudienceOption> _circleOptionsFromState() {
    final groups = ref.read(groupsProvider);
    return groups
        .map((group) => _AudienceOption(id: group.groupId, label: group.name))
        .toList();
  }

  List<_AudienceOption> _inviteUserOptionsFromState() {
    final friends = ref.read(friendsProvider);
    return friends
        .map(
          (friend) =>
              _AudienceOption(id: friend.userId, label: friend.displayName),
        )
        .toList();
  }

  Future<Set<String>?> _showAudiencePicker({
    required String title,
    required List<_AudienceOption> options,
    required Set<String> initialSelection,
  }) async {
    return showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final selected = {...initialSelection};
        return StatefulBuilder(
          builder:
              (context, setSheetState) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...options.map(
                        (option) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected.contains(option.id),
                          title: Text(
                            option.label,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onChanged: (checked) {
                            setSheetState(() {
                              if (checked == true) {
                                selected.add(option.id);
                              } else {
                                selected.remove(option.id);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _kActionBlue,
                              ),
                              onPressed:
                                  () => Navigator.of(context).pop(selected),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  Future<void> _handleCreateTapped(
    _InferredPlan autoPlan,
    String? validationMessage,
  ) async {
    if (validationMessage == null) {
      await _createSpark();
      return;
    }

    if (_isManualMode) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationMessage),
          backgroundColor: AppColors.danger,
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
          content: Text(
            'Time auto-set to in 30 min. You can edit it in Preview.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(validationMessage)));
  }

  _InferredPlan _effectiveAutoPlan() {
    final selectedLocation = ref.read(selectedLocationProvider);
    final input = _planController.text.trim();
    final lower = input.toLowerCase();
    final fallback = _inferPlan(
      input: input,
      selectedLocation: selectedLocation,
    );
    final hasFreshAi =
        _aiInferred != null &&
        _lastAiInput == input &&
        _lastAiLocation == selectedLocation;
    final plan = hasFreshAi ? _aiInferred! : fallback;
    final timeIntent = _timeIntentFromInput(lower);
    final deterministicTime = _inferStartsAt(lower, DateTime.now());
    DateTime? startsAt = _autoTimeOverride;
    if (startsAt == null) {
      if (timeIntent.kind == _TimeIntentKind.resolved &&
          deterministicTime != null) {
        startsAt = deterministicTime;
      } else if (timeIntent.kind == _TimeIntentKind.ambiguous) {
        startsAt = _resolveAmbiguousTime(timeIntent);
      } else {
        startsAt =
            deterministicTime ??
            plan.startsAt ??
            DateTime.now().add(const Duration(minutes: 30));
      }
    }

    return plan.copyWith(
      title: _sanitizeSparkTitle(plan.title),
      startsAt: startsAt,
      locationName:
          (_autoLocationOverride?.trim().isNotEmpty ?? false)
              ? _autoLocationOverride!.trim()
              : plan.locationName,
      maxSpots: _autoSpotsOverride ?? plan.maxSpots,
      note:
          (_autoNoteOverride?.trim().isNotEmpty ?? false)
              ? _autoNoteOverride!.trim()
              : plan.note,
    );
  }

  _TimeIntent _timeIntentFromInput(String lower) {
    if (RegExp(
      r'in\s+\d{1,3}\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours)',
    ).hasMatch(lower)) {
      return const _TimeIntent(kind: _TimeIntentKind.resolved);
    }

    final explicit = RegExp(
      r'\bat\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
    ).firstMatch(lower);
    if (explicit == null)
      return const _TimeIntent(kind: _TimeIntentKind.missing);

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
      final parsed = await ref
          .read(planParseApiRepositoryProvider)
          .parsePlan(input: input, locationHint: selectedLocation);
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
    if (lower.contains('study') ||
        lower.contains('dsa') ||
        lower.contains('library')) {
      return SparkCategory.study;
    }
    if (lower.contains('ride') ||
        lower.contains('airport') ||
        lower.contains('cab')) {
      return SparkCategory.ride;
    }
    if (lower.contains('event') ||
        lower.contains('show') ||
        lower.contains('open mic')) {
      return SparkCategory.events;
    }
    if (lower.contains('coffee') ||
        lower.contains('chai') ||
        lower.contains('hangout')) {
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
            .map(
              (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
            )
            .join(' ');
      }
    }
    return fallbackLocation;
  }

  DateTime? _inferStartsAt(String lower, DateTime now) {
    final inMinutesMatch = RegExp(
      r'in\s+(\d{1,3})\s*(m|min|mins|minute|minutes)',
    ).firstMatch(lower);
    if (inMinutesMatch != null) {
      final mins = int.tryParse(inMinutesMatch.group(1) ?? '') ?? 30;
      return now.add(Duration(minutes: mins.clamp(1, 24 * 60)));
    }
    final inHoursMatch = RegExp(
      r'in\s+(\d{1,2})\s*(h|hr|hrs|hour|hours)',
    ).firstMatch(lower);
    if (inHoursMatch != null) {
      final hours = int.tryParse(inHoursMatch.group(1) ?? '') ?? 1;
      return now.add(Duration(hours: hours.clamp(1, 24)));
    }
    final explicitTime = RegExp(
      r'(?:at\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    ).firstMatch(lower);
    if (explicitTime != null) {
      final meridiem = explicitTime.group(3);
      if (meridiem == null) return null;
      final rawHour = int.tryParse(explicitTime.group(1) ?? '');
      final rawMinute = int.tryParse(explicitTime.group(2) ?? '0') ?? 0;
      if (rawHour == null || rawHour < 1 || rawHour > 12) return null;
      final hour24 =
          meridiem == 'am'
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
    final spotsMatch = RegExp(
      r'(\d{1,2})\s*(spots|spot|people|ppl)',
    ).firstMatch(lower);
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
      RegExp(
        r'\b(in\s+\d{1,3}\s*(?:m|min|mins|minute|minutes|h|hr|hrs|hour|hours))\b',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'\b(at\s*\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\b(today|tonight|tomorrow|now)\b', caseSensitive: false),
      '',
    );

    // Remove location hint from title ("near ...").
    text = text.replaceAll(RegExp(r'\bnear\s+.+$', caseSensitive: false), '');

    // Normalize spacing/punctuation left after cleanup.
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    text = text.replaceAll(RegExp(r'[\s,.;:-]+$'), '').trim();

    if (text.isEmpty) return 'Quick plan';
    return text;
  }

  String? _autoValidationMessage(_InferredPlan plan) {
    if (_planController.text.trim().isEmpty)
      return 'Type one line to create spark';
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
    return RegExp(
      r'(\d{1,2})\s*(spot|spots|seat|seats|people|ppl)',
    ).hasMatch(lower);
  }

  String? _manualValidationMessage() {
    final normalizedTitle = _normalizedTitle(_manualTitleController.text);
    if (normalizedTitle.isEmpty) return 'Title is required';
    if (normalizedTitle.length < 3)
      return 'Title should be at least 3 characters';
    if (_manualVisibility == SparkVisibility.circle &&
        _selectedCircleIds.isEmpty) {
      return 'Pick at least one group for circle-only spark.';
    }
    if (_manualVisibility == SparkVisibility.invite &&
        _manualInvitePhones.isEmpty) {
      return 'Add at least one phone number for private spark.';
    }
    final location =
        _manualLocationController.text.trim().isEmpty
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
    final cleanedTitle = _normalizedTitle(_manualTitleController.text);
    if (cleanedTitle != _manualTitleController.text) {
      _manualTitleController.text = cleanedTitle;
      _manualTitleController.selection = TextSelection.fromPosition(
        TextPosition(offset: _manualTitleController.text.length),
      );
    }
    if (_isCreatingSpark) return;
    setState(() {
      _isCreatingSpark = true;
      _guestPhoneInlineError = null;
    });

    final draft = _isManualMode ? _manualDraft() : _effectiveAutoPlan();
    Spark createdSpark;
    try {
      if (_isEditMode) {
        createdSpark = await ref
            .read(sparkDataControllerProvider)
            .updateSpark(
              sparkId: widget.prefill!.id,
              category: draft.category,
              title: draft.title,
              note: draft.note,
              locationName: draft.locationName,
              startsAt:
                  draft.startsAt ??
                  DateTime.now().add(const Duration(minutes: 30)),
              maxSpots: draft.maxSpots,
              visibility: _manualVisibility,
              circleIds: _selectedCircleIds.toList(),
              inviteUserIds: [..._selectedInviteUserIds, ..._manualInvitePhones],
              recurrenceType: _isRecurring ? _recurrenceType : null,
              recurrenceDayOfWeek:
                  (_isRecurring && _recurrenceType == 'WEEKLY')
                      ? _recurrenceDayOfWeek
                      : null,
              recurrenceTime:
                  _isRecurring
                      ? '${_manualHour.toString().padLeft(2, '0')}:${_manualMinute.toString().padLeft(2, '0')}'
                      : null,
              recurrenceEndDate: _isRecurring ? _recurrenceEndDate : null,
            );
      } else {
        createdSpark = await ref
            .read(sparkDataControllerProvider)
            .createSpark(
              category: draft.category,
              title: draft.title,
              note: draft.note,
              locationName: draft.locationName,
              startsAt:
                  draft.startsAt ??
                  DateTime.now().add(const Duration(minutes: 30)),
              maxSpots: draft.maxSpots,
              visibility: _manualVisibility,
              circleIds: _selectedCircleIds.toList(),
              inviteUserIds: [..._selectedInviteUserIds, ..._manualInvitePhones],
              recurrenceType: _isRecurring ? _recurrenceType : null,
              recurrenceDayOfWeek:
                  (_isRecurring && _recurrenceType == 'WEEKLY')
                      ? _recurrenceDayOfWeek
                      : null,
              recurrenceTime:
                  _isRecurring
                      ? '${_manualHour.toString().padLeft(2, '0')}:${_manualMinute.toString().padLeft(2, '0')}'
                      : null,
              recurrenceEndDate: _isRecurring ? _recurrenceEndDate : null,
            );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingSpark = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_userFacingSparkError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isCreatingSpark = false);
    }
    final sparkForUi = _sparkWithLocalStartTime(
      createdSpark,
      draft.startsAt ?? DateTime.now().add(const Duration(minutes: 2)),
    );
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    if (_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spark updated')),
      );
      Navigator.of(context).pop();
      return;
    }
    final isPrivateSpark = _manualVisibility == SparkVisibility.invite;
    if (isPrivateSpark) {
      await _showPrivateSparkSuccessSheet(sparkForUi);
      return;
    }
    await showInviteFriendsBottomSheet(
      context: context,
      spark: sparkForUi,
      source: 'post_create',
      onViewSpark: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SparkDetailScreen(spark: sparkForUi),
          ),
        );
      },
    );
    if (!mounted) return;
    ref.read(bottomTabProvider.notifier).state = 0;
  }

  String _sparkShareLink(Spark spark) {
    final shareUrl = spark.shareUrl?.trim();
    if (shareUrl != null && shareUrl.isNotEmpty) return shareUrl;
    return 'https://spark.app/sparks/${spark.id}';
  }

  Spark _sparkWithLocalStartTime(Spark spark, DateTime startsAt) {
    final diffMinutes = startsAt
        .difference(DateTime.now())
        .inMinutes
        .clamp(0, 24 * 60);
    final label =
        diffMinutes == 0 ? 'Starts now' : 'Starts in $diffMinutes min';
    return Spark(
      id: spark.id,
      category: spark.category,
      title: spark.title,
      startsInMinutes: diffMinutes,
      timeLabel: label,
      distanceKm: spark.distanceKm,
      distanceLabel: spark.distanceLabel,
      spotsLeft: spark.spotsLeft,
      maxSpots: spark.maxSpots,
      location: spark.location,
      createdBy: spark.createdBy,
      participants: spark.participants,
      visibility: spark.visibility,
      hostPhoneNumber: spark.hostPhoneNumber,
      hideHostPhoneNumber: spark.hideHostPhoneNumber,
      note: spark.note,
      shareUrl: spark.shareUrl,
      recurrenceType: spark.recurrenceType,
    );
  }

  Future<void> _showPrivateSparkSuccessSheet(Spark spark) async {
    final link = _sparkShareLink(spark);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Private spark created',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Generate and share your private spark link.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      link,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: link));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Link copied')),
                            );
                          },
                          child: const Text('Copy link'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _kActionBlue,
                          ),
                          onPressed: () async {
                            await Share.share(
                              'Join my private spark: ${spark.title}\n$link',
                              subject: 'Private Spark Invite',
                            );
                          },
                          child: const Text('Share link'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SparkDetailScreen(spark: spark),
                          ),
                        );
                      },
                      child: const Text('View spark'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  String _userFacingSparkError(Object error) {
    final isEdit = _isEditMode;
    String raw = error.toString();

    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      if (isEdit && (statusCode == 404 || statusCode == 405)) {
        return 'Edit API is unavailable on backend. Please redeploy latest backend build.';
      }
      if (data is Map<String, dynamic>) {
        final serverMsg = data['message'] ?? data['error'] ?? data['detail'];
        if (serverMsg is String && serverMsg.trim().isNotEmpty) {
          raw = serverMsg.trim();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        raw = data.trim();
      }
    }

    final lower = raw.toLowerCase();

    if (lower.contains('only active sparks can be edited')) {
      return 'This spark can no longer be edited because it is no longer active.';
    }

    if (lower.contains('only the host can edit')) {
      return 'Only the organizer can edit this spark.';
    }

    if (lower.contains('spark not found')) {
      return 'This spark is no longer available to edit.';
    }

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

    if (lower.contains('note') &&
        (lower.contains('max') || lower.contains('word'))) {
      return 'Please keep your note concise (up to 15 words).';
    }

    if (lower.contains('24') || lower.contains('within next 24')) {
      return 'Spark time must be within the next 24 hours.';
    }

    if (lower.contains('time') && lower.contains('required')) {
      return 'Please add a clear time like “6 PM” or “in 30 min”.';
    }

    if (lower.contains('location')) {
      return isEdit
          ? 'Please choose a valid place / venue before saving changes.'
          : 'Please choose a valid place / venue before creating the spark.';
    }

    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Connection issue. Please try again in a moment.';
    }

    if (error is DioException && (error.response?.statusCode ?? 0) >= 500) {
      return 'Server is busy right now. Please try again shortly.';
    }

    if (raw.trim().isNotEmpty &&
        raw != error.toString() &&
        raw.length <= 180) {
      return raw;
    }

    return isEdit
        ? 'Could not save spark changes right now. Please try again.'
        : 'Could not create spark right now. Please try again.';
  }

  void _hydrateManualFromAuto(_InferredPlan plan) {
    _manualTitleController.text = plan.title;
    _manualLocationController.text = plan.locationName;
    _manualSpotsController.text = '${plan.maxSpots}';
    _manualNoteController.text = plan.note ?? '';
    _manualCategory = plan.category;
    final ts = plan.startsAt ?? DateTime.now().add(const Duration(minutes: 30));
    final ambiguousClock = _extractAmbiguousClock(
      _planController.text.toLowerCase(),
    );

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
    final explicit = RegExp(
      r'\bat\s*(\d{1,2})(?::(\d{2}))?\s*(?!am\b|pm\b)',
      caseSensitive: false,
    ).firstMatch(lower);
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
      title: _normalizedTitle(_manualTitleController.text),
      category: _manualCategory,
      locationName:
          _manualLocationController.text.trim().isEmpty
              ? fallbackLocation
              : _manualLocationController.text.trim(),
      startsAt: _manualStartsAt(),
      maxSpots: _manualOpenGroup ? 20 : _manualSpotsValue(),
      note:
          _manualNoteController.text.trim().isEmpty
              ? null
              : _manualNoteController.text.trim(),
      source: 'manual',
    );
  }

  DateTime _manualStartsAt() {
    final hour24 =
        _manualPeriod == 'AM'
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
      lastDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1)),
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
      builder:
          (_) => SafeArea(
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
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );
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
      builder:
          (_) => LocationPickerSheet(
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
    final controller = TextEditingController(
      text: '${_autoSpotsOverride ?? plan.maxSpots}',
    );
    final result = await showDialog<int>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              plan.category == SparkCategory.ride
                  ? 'Set seats'
                  : 'How many people?',
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText:
                    plan.category == SparkCategory.ride
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
                    backgroundColor: _kActionBlue,
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
      builder:
          (_) => AlertDialog(
            title: const Text('Add details'),
            content: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 2,
              inputFormatters: [_WordLimitFormatter(maxWords: 15)],
              decoration: const InputDecoration(
                hintText: 'Optional note (max 15 words)',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kActionBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
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
      builder:
          (_) => SafeArea(
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
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    _setManualTimeFromDateTime(candidate);
  }

  void _setManualTimeFromDateTime(DateTime ts) {
    final snappedMinute = ((ts.minute + 7) ~/ 15) * 15;
    final snapped = DateTime(ts.year, ts.month, ts.day, ts.hour, snappedMinute);
    setState(() {
      _manualSelectedDate = DateTime(snapped.year, snapped.month, snapped.day);
      _manualHour = _to12Hour(snapped.hour);
      _manualMinute = snapped.minute;
      _manualPeriod = snapped.hour >= 12 ? 'PM' : 'AM';
    });
  }

  String _normalizedTitle(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isNearYouLocationLabel(String location) {
    final normalized = location.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'near you' ||
        normalized == 'nearby' ||
        normalized == 'current location';
  }

  Future<void> _editManualSpots() async {
    final controller = TextEditingController(
      text:
          _manualSpotsController.text.trim().isEmpty
              ? '3'
              : _manualSpotsController.text.trim(),
    );
    final result = await showDialog<int>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              _manualCategory == SparkCategory.ride
                  ? 'How many seats?'
                  : 'How many people?',
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText:
                    _manualCategory == SparkCategory.ride
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
                    backgroundColor: _kActionBlue,
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
    final controller = TextEditingController(
      text: _manualNoteController.text.trim(),
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _BottomSheetCard(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Add details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add any extra information about your spark.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 5,
                    autofocus: true,
                    inputFormatters: [_WordLimitFormatter(maxWords: 50)],
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Meeting at the north gate, look for the red flag.',
                      hintStyle: const TextStyle(
                        color: Color(0xFFC7C7CC),
                        fontSize: 14,
                      ),
                      fillColor: AppColors.background,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Save',
                    onPressed:
                        () => Navigator.of(ctx).pop(controller.text.trim()),
                  ),
                ],
              ),
            ),
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
      builder:
          (_) => LocationPickerSheet(
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
          color: selected ? _kActionBlue : Colors.transparent,
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

  bool _isNearYouAlias(String locationName) {
    final normalized = locationName.trim().toLowerCase();
    return normalized == 'near you' ||
        normalized == 'nearby' ||
        normalized == 'current location';
  }

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
                  color: AppColors.accentSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  plan.category.icon,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ReadOnlyMetaChip(
            icon: Icons.place_outlined,
            value:
                _isNearYouAlias(plan.locationName)
                    ? '${plan.locationName} (near you)'
                    : plan.locationName,
          ),
          const SizedBox(height: 6),
          _ReadOnlyMetaChip(
            icon: Icons.schedule_outlined,
            value:
                relativeTimeText == null
                    ? timeText
                    : '$relativeTimeText • $timeText',
          ),
          const SizedBox(height: 6),
          _ReadOnlyMetaChip(
            icon: Icons.group_outlined,
            value:
                plan.category == SparkCategory.ride
                    ? '${plan.maxSpots} seats'
                    : (hasExplicitSpots
                        ? '${plan.maxSpots} people'
                        : 'Open group'),
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
            decoration: const InputDecoration(
              hintText: 'Cricket at 6 near Central Park',
            ),
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
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
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
            children:
                SparkCategory.values
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => onCategoryChanged(c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  c == category
                                      ? AppColors.accent
                                      : AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    c == category
                                        ? AppColors.accent
                                        : AppColors.chipBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  c.icon,
                                  size: 13,
                                  color:
                                      c == category
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  c.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        c == category
                                            ? Colors.white
                                            : AppColors.chipText,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                  _ManualDateField(dateLabel: dateLabel, onTap: onPickDate),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: noteController,
                minLines: 1,
                maxLines: 2,
                inputFormatters: [_WordLimitFormatter(maxWords: 15)],
                decoration: const InputDecoration(
                  hintText: 'e.g. Bring your own bat and reach Gate 2',
                ),
              ),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: noteController,
                builder: (context, _) {
                  final text = noteController.text.trim();
                  final wordCount =
                      text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
                  return Text(
                    '$wordCount / 15 words',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color:
                          wordCount >= 14
                              ? AppColors.errorText
                              : AppColors.textMuted,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

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
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            fontFamily: 'Manrope',
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ManualDateField extends StatelessWidget {
  const _ManualDateField({required this.dateLabel, required this.onTap});

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
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
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
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more, size: 16),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surfaceDim,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        items:
            items
                .map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      labelBuilder(item),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
  const _CreateScreenHeader({required this.category, required this.onBackTap});
  final SparkCategory category;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBackTap,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create a spark',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                    fontFamily: 'Manrope',
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Plan something quick & local',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.1,
                    fontFamily: 'Manrope',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Container(
              key: ValueKey(category),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: category.accentColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                category.icon,
                color: category.accentColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _AudiencePickerRow extends StatelessWidget {
  const _AudiencePickerRow({
    required this.title,
    required this.cta,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String cta;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(cta),
          ),
        ],
      ),
    );
  }
}

class _AudienceOption {
  const _AudienceOption({required this.id, required this.label});
  final String id;
  final String label;
}

class _RemovablePill extends StatelessWidget {
  const _RemovablePill({required this.text, required this.onRemove});

  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kActionBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kActionBlueDeep : AppColors.border,
            width: 1,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: _kActionBlueDeep.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
            fontFamily: 'Manrope',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepButton(icon: Icons.remove_rounded, onTap: onDecrease),
          Expanded(
            child: Text(
              '$value people',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontFamily: 'Manrope',
              ),
            ),
          ),
          _StepButton(icon: Icons.add_rounded, onTap: onIncrease),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: AppColors.accent),
      ),
    );
  }
}

class _ReadOnlyMetaChip extends StatelessWidget {
  const _ReadOnlyMetaChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
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
  const _SuggestionChip({required this.label, required this.onTap});

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
  const _TimeIntent({required this.kind, this.hour, this.minute});

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

class _BottomSheetCard extends StatelessWidget {
  const _BottomSheetCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: SafeArea(child: child),
  );
}

/// "Repeat this Spark" toggle + day/type picker for recurring sparks.
class _RecurrenceSection extends StatelessWidget {
  const _RecurrenceSection({
    required this.isRecurring,
    required this.recurrenceType,
    required this.recurrenceDayOfWeek,
    required this.recurrenceEndDate,
    required this.onToggle,
    required this.onTypeChanged,
    required this.onDayChanged,
    required this.onEndDateChanged,
  });

  final bool isRecurring;
  final String recurrenceType;
  final int recurrenceDayOfWeek;
  final DateTime? recurrenceEndDate;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<DateTime?> onEndDateChanged;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutralSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Toggle row
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onToggle(!isRecurring),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.repeat_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Repeat this spark',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: isRecurring,
                    onChanged: onToggle,
                    activeColor: _kActionBlue,
                  ),
                ],
              ),
            ),
          ),
          if (isRecurring) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DAILY / WEEKLY
                  Row(
                    children: [
                      _TypeChip(
                        label: 'Daily',
                        selected: recurrenceType == 'DAILY',
                        onTap: () => onTypeChanged('DAILY'),
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: 'Weekly',
                        selected: recurrenceType == 'WEEKLY',
                        onTap: () => onTypeChanged('WEEKLY'),
                      ),
                    ],
                  ),
                  if (recurrenceType == 'WEEKLY') ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Every',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_days.length, (i) {
                          final day = i + 1; // 1=Mon…7=Sun
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _TypeChip(
                              label: _days[i],
                              selected: recurrenceDayOfWeek == day,
                              onTap: () => onDayChanged(day),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // End date (optional)
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            recurrenceEndDate ??
                            DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      onEndDateChanged(picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            recurrenceEndDate == null
                                ? 'No end date'
                                : 'Ends ${recurrenceEndDate!.day}/${recurrenceEndDate!.month}/${recurrenceEndDate!.year}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (recurrenceEndDate != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => onEndDateChanged(null),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kActionBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kActionBlueDeep : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}


// ──────────────────────────────────────────────────────────────────────
// New design components for Create Spark redesign (Feb 2026)
// ──────────────────────────────────────────────────────────────────────

/// Soft white card used per-section. Subtle shadow + comfortable padding.
class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section header. Bold title with a tiny accent leader.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
            fontFamily: 'Manrope',
          ),
        ),
      ],
    );
  }
}

/// Large, friendly title input. Borderless on a soft tinted bg.
class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        maxLines: 1,
        maxLength: 60,
        textInputAction: TextInputAction.done,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
          fontFamily: 'Manrope',
        ),
        decoration: InputDecoration(
          hintText: 'e.g. Cricket at Central Park',
          hintStyle: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.32),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          counterText: '',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: _kActionBlue, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// Horizontal category pill rail. Compact pills, selected = filled with category accent.
class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.selected, required this.onChanged});
  final SparkCategory selected;
  final ValueChanged<SparkCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: SparkCategory.values
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _CategoryPill(
                  category: c,
                  selected: c == selected,
                  onTap: () => onChanged(c),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final SparkCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = category.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 15,
              color: selected ? Colors.white : accent,
            ),
            const SizedBox(width: 7),
            Text(
              category.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary,
                letterSpacing: -0.2,
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick time chips: Now / 30m / 1h / 2h / Custom.
class _TimeChips extends StatelessWidget {
  const _TimeChips({
    required this.startsAt,
    required this.onPickQuick,
    required this.onPickCustom,
  });

  final DateTime startsAt;
  final ValueChanged<DateTime> onPickQuick;
  final VoidCallback onPickCustom;

  int get _diffMinutes => startsAt.difference(DateTime.now()).inMinutes;

  @override
  Widget build(BuildContext context) {
    final diff = _diffMinutes;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _TimePresetChip(
            label: 'Now',
            selected: diff <= 5,
            onTap: () =>
                onPickQuick(DateTime.now().add(const Duration(minutes: 2))),
          ),
          const SizedBox(width: 8),
          _TimePresetChip(
            label: '30 min',
            selected: diff > 5 && diff <= 35,
            onTap: () =>
                onPickQuick(DateTime.now().add(const Duration(minutes: 30))),
          ),
          const SizedBox(width: 8),
          _TimePresetChip(
            label: '1 hr',
            selected: diff > 35 && diff <= 65,
            onTap: () =>
                onPickQuick(DateTime.now().add(const Duration(hours: 1))),
          ),
          const SizedBox(width: 8),
          _TimePresetChip(
            label: '2 hr',
            selected: diff > 65 && diff <= 125,
            onTap: () =>
                onPickQuick(DateTime.now().add(const Duration(hours: 2))),
          ),
          const SizedBox(width: 8),
          _TimePresetChip(
            label: 'Custom',
            icon: Icons.edit_calendar_rounded,
            selected: diff > 125,
            onTap: onPickCustom,
          ),
        ],
      ),
    );
  }
}

class _TimePresetChip extends StatelessWidget {
  const _TimePresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kActionBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kActionBlueDeep : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kActionBlueDeep.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Today, 6:30 PM · in 30 min" confirmation pill.
class _TimeConfirmation extends StatelessWidget {
  const _TimeConfirmation({required this.label, required this.relative});
  final String label;
  final String relative;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.access_time_filled_rounded,
            size: 16,
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
                letterSpacing: -0.2,
                fontFamily: 'Manrope',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· $relative',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.accent.withValues(alpha: 0.75),
              fontFamily: 'Manrope',
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable row showing the chosen place (flat — no inner card).
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.location,
    required this.isNearYou,
    required this.onTap,
  });

  final String location;
  final bool isNearYou;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isNearYou
                          ? 'We\'ll use your current area'
                          : 'Tap to change place',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated public/private segmented toggle.
class _VisibilitySegmented extends StatelessWidget {
  const _VisibilitySegmented({
    required this.isPublic,
    required this.onChanged,
  });
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final segWidth = (width - 8) / 2;
        return Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment:
                    isPublic ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: segWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _segmentTile(
                      icon: Icons.public_rounded,
                      label: 'Public',
                      selected: isPublic,
                      onTap: () => onChanged(true),
                    ),
                  ),
                  Expanded(
                    child: _segmentTile(
                      icon: Icons.lock_rounded,
                      label: 'Private',
                      selected: !isPublic,
                      onTap: () => onChanged(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _segmentTile({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                letterSpacing: -0.2,
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Group size block: Open group switch + inline stepper. Flat (no inner card).
class _GroupSizeBlock extends StatelessWidget {
  const _GroupSizeBlock({
    required this.isOpenGroup,
    required this.spots,
    required this.isRideCategory,
    required this.onSetOpen,
    required this.onIncrease,
    required this.onDecrease,
  });

  final bool isOpenGroup;
  final int spots;
  final bool isRideCategory;
  final ValueChanged<bool> onSetOpen;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.public_rounded,
                size: 16,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Open group',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isOpenGroup
                        ? 'Anyone can join — no spot limit.'
                        : 'Limited spots. Tap to switch.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.92,
              child: Switch.adaptive(
                value: isOpenGroup,
                onChanged: onSetOpen,
                activeColor: _kActionBlue,
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: isOpenGroup
              ? const SizedBox(width: double.infinity, height: 0)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _InlineStepper(
                    value: spots,
                    label: isRideCategory
                        ? (spots == 1 ? 'seat' : 'seats')
                        : (spots == 1 ? 'spot' : 'spots'),
                    onIncrease: onIncrease,
                    onDecrease: onDecrease,
                  ),
                ),
        ),
      ],
    );
  }
}

class _InlineStepper extends StatelessWidget {
  const _InlineStepper({
    required this.value,
    required this.label,
    required this.onIncrease,
    required this.onDecrease,
  });

  final int value;
  final String label;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepCircle(
          icon: Icons.remove_rounded,
          enabled: value > 1,
          onTap: onDecrease,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: RichText(
                key: ValueKey(value),
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Manrope'),
                  children: [
                    TextSpan(
                      text: '$value',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    TextSpan(
                      text: '  $label',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        _StepCircle(
          icon: Icons.add_rounded,
          enabled: value < 20,
          onTap: onIncrease,
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.accent.withValues(alpha: 0.1)
                : AppColors.border.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? AppColors.accent
                : AppColors.textMuted.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// Tappable note / details row (flat — no inner card).
class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.onTap});
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isEmpty = note.isEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.notes_rounded,
                  size: 17,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isEmpty ? 'Add details' : note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isEmpty
                            ? AppColors.textPrimary.withValues(alpha: 0.55)
                            : AppColors.textPrimary,
                        letterSpacing: -0.3,
                        fontFamily: 'Manrope',
                      ),
                    ),
                    if (isEmpty) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Tell guests what to bring or where to meet',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isEmpty ? Icons.add_rounded : Icons.edit_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sticky bottom bar: live preview + create CTA.
class _StickyCreateBar extends StatelessWidget {
  const _StickyCreateBar({
    required this.title,
    required this.location,
    required this.timeRelative,
    required this.spotsLabel,
    required this.category,
    required this.ctaLabel,
    required this.loading,
    required this.onPressed,
  });

  final String title;
  final String location;
  final String timeRelative;
  final String spotsLabel;
  final SparkCategory category;
  final String ctaLabel;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = category.accentColor;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live preview row
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(category.icon, size: 14, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                            fontFamily: 'Manrope',
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$timeRelative · $location · $spotsLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: -0.1,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kActionBlue,
                  disabledBackgroundColor:
                      _kActionBlue.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.bolt_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      ctaLabel,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        fontFamily: 'Manrope',
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
