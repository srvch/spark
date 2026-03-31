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
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You are in',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.spark.title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFF2F426F),
                  ),
                  onPressed: () {
                    ref.read(analyticsServiceProvider).track(
                      'open_chat_from_join_sheet',
                      properties: {'spark_id': widget.spark.id},
                    );
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(spark: widget.spark),
                      ),
                    );
                  },
                  child: const Text('OPEN CHAT'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    showInviteFriendsBottomSheet(
                      context: this.context,
                      spark: widget.spark,
                      source: 'post_join',
                    );
                  },
                  child: const Text('INVITE FRIENDS'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _openInMaps(this.context),
                  child: const Text('VIEW LOCATION ON MAP'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _openSafetyGuidelines,
                  child: const Text('SAFETY GUIDELINES'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    unawaited(_leaveSpark(showMessage: false));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('You left this spark')),
                    );
                  },
                  child: const Text(
                    'LEAVE SPARK',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
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
    final spotsColor = spark.spotsLeft <= 1
        ? const Color(0xFFDC2626)
        : spark.spotsLeft <= 2
        ? const Color(0xFFF59E0B)
        : const Color(0xFF16A34A);
    final fillRatio = ((spark.maxSpots - spark.spotsLeft) / spark.maxSpots).clamp(
      0.0,
      1.0,
    ).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Spark')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScaleTransition(
                scale: _joinScale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: joined ? const Color(0xFF2F426F) : AppColors.border,
                      width: joined ? 1.3 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x10000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            spark.category.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _copyShareLink,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.share_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (joined)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Joined',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F426F),
                              ),
                            ),
                          )
                        else if (spark.startsInMinutes <= 30)
                          const Text(
                            'Starting soon',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEA580C),
                            ),
                          ),
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
                        _MetaInline(icon: Icons.schedule_outlined, text: spark.timeLabel),
                        const SizedBox(width: 16),
                        _MetaInline(icon: Icons.place_outlined, text: spark.distanceLabel),
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
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
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
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Reliable host',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F426F),
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
                            const Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
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
                                foregroundColor: const Color(0xFF2F426F),
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
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
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
                              foregroundColor: const Color(0xFF2F426F),
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
                    const Divider(height: 1, color: AppColors.border),
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
                            foregroundColor: const Color(0xFF2F426F),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: fillRatio,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(spotsColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${spark.spotsLeft} left',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: spotsColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${spark.maxSpots - spark.spotsLeft}/${spark.maxSpots} spots filled',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: (!joined && !isCreator)
                    ? PrimaryButton(
                        key: const ValueKey('join-btn'),
                        label: 'JOIN SPARK',
                        backgroundColor: const Color(0xFF2F426F),
                        onPressed: _joinSpark,
                      )
                    : (isCreator
                        ? Row(
                            key: const ValueKey('creator-actions'),
                            children: [
                              Expanded(
                                child: PrimaryButton(
                                  label: 'OPEN HOST CHAT',
                                  compact: true,
                                  backgroundColor: const Color(0xFF2F426F),
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
                                    'SHARE INVITE',
                                    style: TextStyle(
                                      color: Color(0xFF2F426F),
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
                              label: 'OPEN CHAT',
                              compact: true,
                              backgroundColor: const Color(0xFF2F426F),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _leaveSpark(),
                              child: Text(
                                'LEAVE',
                                style: TextStyle(
                                  color: const Color(0xFFDC2626),
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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Safety Guidelines',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Please review before meetup.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...guidelines.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key + 1}.',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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
                    color: const Color(0xFFF8FAFC),
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
        badgeColor: const Color(0xFF2F426F),
      ),
    ];

    if (isJoined && creatorName != 'You') {
      rows.add(
        _ParticipantRowData(
          initials: 'ME',
          name: 'You',
          role: 'Participant',
          badge: 'Verified',
          badgeColor: const Color(0xFF0F766E),
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
          badgeColor: const Color(0xFF0F766E),
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
        color: const Color(0xFFE2E8F0),
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
