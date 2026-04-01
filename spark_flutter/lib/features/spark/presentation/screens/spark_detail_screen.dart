import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/chat/presentation/screens/chat_screen.dart';
import '../../../../shared/widgets/invite_friends_sheet.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../data/safety_api_repository.dart';
import '../../domain/spark.dart';
import '../controllers/spark_controller.dart';

final safetyApiRepositoryProvider = Provider<SafetyApiRepository>((ref) {
  return SafetyApiRepository(dio: ref.watch(dioProvider));
});

class SparkDetailScreen extends ConsumerStatefulWidget {
  const SparkDetailScreen({super.key, required this.spark});
  final Spark spark;

  @override
  ConsumerState<SparkDetailScreen> createState() => _SparkDetailScreenState();
}

class _SparkDetailScreenState extends ConsumerState<SparkDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _joinPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _joinScale = Tween<double>(begin: 1, end: 1.015)
      .animate(CurvedAnimation(parent: _joinPulseController, curve: Curves.easeOut));

  @override
  void dispose() {
    _joinPulseController.dispose();
    super.dispose();
  }

  Future<void> _openInMaps(BuildContext context) async {
    final encoded = Uri.encodeComponent(widget.spark.location);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps right now.')),
      );
    }
  }

  Future<void> _joinSpark() async {
    final alreadyJoined = ref.read(joinedSparkIdsProvider).contains(widget.spark.id);
    if (alreadyJoined) return;
    try {
      await ref.read(sparkDataControllerProvider).joinSpark(widget.spark.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      return;
    }

    await _joinPulseController.forward(from: 0);
    await _joinPulseController.reverse();
    if (!mounted) return;
    unawaited(_showJoinedSheet());
  }

  Future<void> _leaveSpark({bool showMessage = true}) async {
    await ref.read(sparkDataControllerProvider).leaveSpark(widget.spark.id);
    if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You left this spark')),
      );
    }
  }

  Future<void> _showJoinedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.pillSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 30, color: AppColors.accent),
                ),
                const SizedBox(height: 12),
                const Text(
                  "You're in!",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.spark.title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      widget.spark.timeLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.near_me_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      widget.spark.distanceLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    ref.read(analyticsServiceProvider).track(
                      'open_chat_from_join_sheet',
                      properties: {'spark_id': widget.spark.id},
                    );
                    Navigator.of(ctx).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(spark: widget.spark),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: const Text('Open Chat'),
                ),
                const SizedBox(height: 12),
                _JoinedActionTile(
                  icon: Icons.person_add_rounded,
                  label: 'Invite friends',
                  subtitle: 'Fill spots faster by sharing',
                  onTap: () => showInviteFriendsBottomSheet(
                    context: this.context,
                    spark: widget.spark,
                    source: 'post_join',
                  ),
                ),
                _JoinedActionTile(
                  icon: Icons.map_rounded,
                  label: 'View location on map',
                  subtitle: widget.spark.location,
                  onTap: () => _openInMaps(this.context),
                ),
                _JoinedActionTile(
                  icon: Icons.shield_rounded,
                  label: 'Safety guidelines',
                  subtitle: 'Review before meetup',
                  onTap: _openSafetyGuidelines,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () {
                      unawaited(_leaveSpark(showMessage: false));
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('You left this spark')),
                      );
                    },
                    child: const Text(
                      'Leave spark',
                      style: TextStyle(
                        color: AppColors.errorText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyShareLink() async {
    final deepLink = 'https://spark.app/sparks/${widget.spark.id}';
    await Clipboard.setData(ClipboardData(text: deepLink));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Spark link copied')),
    );
    ref.read(analyticsServiceProvider).track(
      'spark_link_copied',
      properties: {'spark_id': widget.spark.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allSparksProvider);
    Spark spark = widget.spark;
    for (final item in all) {
      if (item.id == widget.spark.id) {
        spark = item;
        break;
      }
    }
    final currentUserId = ref.watch(currentUserIdProvider);
    final selectedLocation = ref.watch(selectedLocationProvider);
    final isCreator = spark.createdBy == currentUserId;
    final joined = ref.watch(joinedSparkIdsProvider).contains(spark.id);
    final creatorLabel = _creatorDisplayName(
      createdByRaw: spark.createdBy,
      currentUserId: currentUserId,
    );
    final locationLabel = _resolvedLocationLabel(
      rawLocation: spark.location,
      selectedLocation: selectedLocation,
    );
    final fillRatio = ((spark.maxSpots - spark.spotsLeft) / spark.maxSpots).clamp(
      0.0,
      1.0,
    ).toDouble();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          spark.category.label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _copyShareLink,
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScaleTransition(
                scale: _joinScale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: joined ? AppColors.accent : AppColors.border,
                      width: joined ? 1.3 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.cardShadow,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.neutralSurface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            spark.category.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (joined)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSurface,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 12, color: AppColors.accent),
                                SizedBox(width: 4),
                                Text(
                                  'Joined',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (spark.startsInMinutes <= 30)
                          _CountdownBadge(minutes: spark.startsInMinutes),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      spark.title,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (spark.note != null && spark.note!.trim().isNotEmpty) ...[
                      Text(
                        spark.note!,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        _StatPill(
                          icon: Icons.schedule_rounded,
                          text: spark.timeLabel,
                          color: AppColors.accent,
                          bg: AppColors.neutralSurface,
                        ),
                        const SizedBox(width: 8),
                        _StatPill(
                          icon: Icons.near_me_rounded,
                          text: spark.distanceLabel,
                          color: AppColors.accent,
                          bg: AppColors.neutralSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 15,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Created by $creatorLabel',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSurface,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Reliable host',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (spark.hostPhoneNumber != null &&
                        spark.hostPhoneNumber!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.iconBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone_outlined,
                                size: 15,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                spark.hostPhoneNumber!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () => _callHost(spark.hostPhoneNumber!),
                              child: const Text(
                                'Call host',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              locationLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _openInMaps(context),
                            child: const Text(
                              'View map',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.cardDivider),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'Participants',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 28),
                          ),
                          onPressed: () => _openParticipantsSheet(
                            spark: spark,
                            currentUserId: currentUserId,
                            isJoined: joined,
                          ),
                          child: const Text(
                            'See participants',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ParticipantStack(participants: spark.participants),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '${spark.participants.length} joined',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (spark.maxSpots > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: fillRatio,
                          minHeight: 7,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${spark.maxSpots - spark.spotsLeft}/${spark.maxSpots} spots filled',
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
                          Text(
                            '${spark.spotsLeft} ${spark.spotsLeft == 1 ? 'spot' : 'spots'} left',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Open group · anyone can join',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: (!joined && !isCreator)
                    ? (spark.spotsLeft == 0
                        ? SizedBox(
                            key: const ValueKey('full-btn'),
                            height: 50,
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.pillSurface,
                                foregroundColor: AppColors.textMuted,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: null,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 16),
                                  SizedBox(width: 7),
                                  Text('Spark Full',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                ],
                              ),
                            ),
                          )
                        : PrimaryButton(
                            key: const ValueKey('join-btn'),
                            label: 'Join Spark',
                            backgroundColor: AppColors.accent,
                            onPressed: _joinSpark,
                          ))
                    : (isCreator
                        ? Row(
                            key: const ValueKey('creator-actions'),
                            children: [
                              Expanded(
                                child: PrimaryButton(
                                  label: 'Open Host Chat',
                                  compact: true,
                                  backgroundColor: AppColors.accent,
                                  onPressed: () {
                                    ref.read(analyticsServiceProvider).track(
                                      'open_chat_from_detail',
                                      properties: {'spark_id': spark.id},
                                    );
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(spark: spark),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    showInviteFriendsBottomSheet(
                                      context: context,
                                      spark: spark,
                                      source: 'detail_host',
                                    );
                                  },
                                  child: const Text(
                                    'Share Invite',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                        key: const ValueKey('joined-actions'),
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Open Chat',
                              compact: true,
                              backgroundColor: AppColors.accent,
                              onPressed: () {
                                ref.read(analyticsServiceProvider).track(
                                  'open_chat_from_detail',
                                  properties: {'spark_id': widget.spark.id},
                                );
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(spark: widget.spark),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                foregroundColor: AppColors.onSurfaceStrong,
                                side: const BorderSide(
                                    color: AppColors.chipBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _leaveSpark(),
                              child: const Text(
                                'Leave',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _creatorDisplayName({
    required String createdByRaw,
    required String currentUserId,
  }) {
    if (createdByRaw == currentUserId) return 'You';
    final looksLikeId = RegExp(r'^[0-9a-fA-F-]{24,}$').hasMatch(createdByRaw);
    if (looksLikeId) return 'Spark host';
    return createdByRaw;
  }

  String _resolvedLocationLabel({
    required String rawLocation,
    required String selectedLocation,
  }) {
    final raw = rawLocation.trim();
    if (raw.isEmpty) return selectedLocation;
    final lower = raw.toLowerCase();
    if ((lower == 'current location' || lower == 'nearby') &&
        selectedLocation.trim().isNotEmpty &&
        selectedLocation.toLowerCase() != 'current location') {
      return selectedLocation;
    }
    return raw;
  }

  Future<void> _callHost(String phone) async {
    final uri = Uri.parse('tel:${Uri.encodeComponent(phone)}');
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer right now.')),
      );
    }
  }

  Future<void> _openSafetyGuidelines() async {
    List<String> guidelines = const [];
    try {
      guidelines = await ref.read(safetyApiRepositoryProvider).fetchGuidelines();
    } catch (_) {
      guidelines = const [
        'Meet only in public, well-lit places.',
        'Share spark details with a trusted contact.',
        'Prefer verified hosts and public meetup points.',
        'Do not share OTPs or financial details.',
        'If unsafe, leave immediately and trigger SOS.',
      ];
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warmSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 22,
                      color: AppColors.warmAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Guidelines',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Please review before meetup',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...guidelines.asMap().entries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Understood',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openParticipantsSheet({
    required Spark spark,
    required String currentUserId,
    required bool isJoined,
  }) async {
    final rows = _buildParticipantRows(
      spark: spark,
      currentUserId: currentUserId,
      isJoined: isJoined,
    );

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Participants',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${rows.length} people in this spark',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...rows.map(
                (row) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _ParticipantChip(text: row.initials),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              row.role,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: row.badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          row.badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: row.badgeColor,
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
    );
  }

  List<_ParticipantRowData> _buildParticipantRows({
    required Spark spark,
    required String currentUserId,
    required bool isJoined,
  }) {
    final creatorName = _creatorDisplayName(
      createdByRaw: spark.createdBy,
      currentUserId: currentUserId,
    );
    final rows = <_ParticipantRowData>[
      _ParticipantRowData(
        initials: _toInitials(creatorName),
        name: creatorName,
        role: 'Host',
        badge: 'Reliable host',
        badgeColor: AppColors.accent,
      ),
    ];

    if (isJoined && creatorName != 'You') {
      rows.add(
        _ParticipantRowData(
          initials: 'ME',
          name: 'You',
          role: 'Participant',
          badge: 'Verified',
          badgeColor: AppColors.tealAccent,
        ),
      );
    }

    for (var i = 0; i < spark.participants.length; i++) {
      final initial = spark.participants[i];
      rows.add(
        _ParticipantRowData(
          initials: initial,
          name: _nameFromInitial(initial, i),
          role: 'Participant',
          badge: 'Verified',
          badgeColor: AppColors.tealAccent,
        ),
      );
    }

    final byIdentity = <String, _ParticipantRowData>{};
    for (final row in rows) {
      byIdentity.putIfAbsent('${row.role}:${row.name}', () => row);
    }
    return byIdentity.values.toList();
  }

  static String _nameFromInitial(String raw, int index) {
    const fallback = ['Rahul', 'Sneha', 'Aditya', 'Meera', 'Karan', 'Priya'];
    if (raw.trim().length > 2) return raw;
    if (raw.trim().isEmpty) return fallback[index % fallback.length];
    final upper = raw.trim().toUpperCase();
    return switch (upper) {
      'AA' => 'Aarav',
      'RK' => 'Rohan',
      'SN' => 'Sneha',
      'VK' => 'Vikram',
      'TJ' => 'Tanvi',
      'PS' => 'Pranav',
      'MD' => 'Madhav',
      'AN' => 'Ananya',
      _ => fallback[index % fallback.length],
    };
  }

  static String _toInitials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _ParticipantRowData {
  const _ParticipantRowData({
    required this.initials,
    required this.name,
    required this.role,
    required this.badge,
    required this.badgeColor,
  });

  final String initials;
  final String name;
  final String role;
  final String badge;
  final Color badgeColor;
}

class _JoinedActionTile extends StatelessWidget {
  const _JoinedActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.accent),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownBadge extends StatefulWidget {
  const _CountdownBadge({required this.minutes});
  final int minutes;

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);
  late final Animation<double> _opacity =
      Tween<double>(begin: 0.5, end: 1.0).animate(_pulse);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.minutes <= 0
        ? 'Starting now'
        : widget.minutes == 1
            ? 'In 1 min'
            : 'In ${widget.minutes} min';
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.warmSurface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 12,
              color: AppColors.warmAccent,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.warmAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaInline extends StatelessWidget {
  const _MetaInline({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ParticipantStack extends StatelessWidget {
  const _ParticipantStack({required this.participants});

  final List<String> participants;

  @override
  Widget build(BuildContext context) {
    final shown = participants.take(3).toList();
    final hasMore = participants.length > 3;
    final total = shown.length + (hasMore ? 1 : 0);
    final width = total == 0 ? 0.0 : (32 + ((total - 1) * 24)).toDouble();

    return SizedBox(
      width: width,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: (i * 24).toDouble(),
              child: _ParticipantChip(text: shown[i]),
            ),
          if (hasMore)
            Positioned(
              left: (shown.length * 24).toDouble(),
              child: _ParticipantChip(text: '+${participants.length - 3}'),
            ),
        ],
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  const _ParticipantChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.border,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
