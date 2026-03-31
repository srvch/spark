import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import '../../../spark/presentation/screens/activity_screen.dart';
import '../../../spark/presentation/screens/spark_detail_screen.dart';
import '../controllers/profile_preferences_controller.dart';

const _kNavy = Color(0xFF2F426F);
const _kNavyLight = Color(0xFFEAF0FF);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _name = 'Saurav';
  String _email = 'spark@saurav.app';
  final String _location = 'Indiranagar, Bengaluru';
  final String _memberSince = 'March 2026';
  final String _referralCode = 'SAURAV10';
  final AnalyticsService _analytics = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    final joined = ref.watch(joinedSparksProvider);
    final created = ref.watch(myCreatedSparksProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final recent = _recentItems(created: created, joined: joined);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Header ───────────────────────────────────────────────
            _ProfileHeader(
              name: _name,
              email: _email,
              location: _location,
              memberSince: _memberSince,
              createdCount: created.length,
              joinedCount: joined.length,
              onEditTap: _openEditProfileSheet,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Your Sparks ──────────────────────────────────
                  _SectionHeader(
                    title: 'Your Sparks',
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ActivityScreen()),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: _kNavy,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'See all',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    subtitle: 'Recent joined & created sparks',
                  ),
                  const SizedBox(height: 10),
                  if (recent.isEmpty)
                    _EmptyCard(
                      icon: Icons.bolt_rounded,
                      message: 'No sparks yet. Join or create one to see activity here.',
                    )
                  else
                    ...recent.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RecentSparkCard(
                          title: item.spark.title,
                          subtitle: '${item.spark.timeLabel} · ${item.spark.location}',
                          tag: item.tag,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SparkDetailScreen(spark: item.spark),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Referral ─────────────────────────────────────
                  _ReferralCard(
                    referralCode: _referralCode,
                    onShare: _shareInvite,
                    onCopyCode: _copyInviteCode,
                  ),

                  const SizedBox(height: 24),

                  // ── Alerts ───────────────────────────────────────
                  _SectionHeader(
                    title: 'Alerts',
                    subtitle: 'Control when Spark notifies you',
                  ),
                  const SizedBox(height: 10),
                  _AlertsCard(
                    startsSoon: notificationPrefs.notifyStartsSoon,
                    fillingFast: notificationPrefs.notifyFillingFast,
                    radiusKm: notificationPrefs.radiusKm,
                    interests: notificationPrefs.interests,
                    onStartsSoonChanged: (v) => ref
                        .read(notificationPreferencesProvider.notifier)
                        .setStartsSoon(v),
                    onFillingFastChanged: (v) => ref
                        .read(notificationPreferencesProvider.notifier)
                        .setFillingFast(v),
                    onRadiusChanged: (km) => ref
                        .read(notificationPreferencesProvider.notifier)
                        .setRadius(km),
                    onInterestToggle: (category) => ref
                        .read(notificationPreferencesProvider.notifier)
                        .toggleInterest(category),
                  ),

                  const SizedBox(height: 24),

                  // ── Safety & Legal ───────────────────────────────
                  _SectionHeader(title: 'Safety & Legal'),
                  const SizedBox(height: 10),
                  _LegalLinks(
                    onSosTap: () {
                      _analytics.track('sos_from_profile_tapped');
                      _openLegalFlow(_LegalType.safety);
                    },
                    onTap: (type) {
                      _analytics.track('legal_link_opened',
                          properties: {'type': type.name});
                      _openLegalFlow(type);
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ProfileRecentItem> _recentItems({
    required List<Spark> created,
    required List<Spark> joined,
  }) {
    final createdMapped =
        created.map((spark) => _ProfileRecentItem(spark, 'Created'));
    final createdIds = created.map((e) => e.id).toSet();
    final joinedMapped = joined
        .where((spark) => !createdIds.contains(spark.id))
        .map((spark) => _ProfileRecentItem(spark, 'Joined'));
    return [...createdMapped, ...joinedMapped].take(3).toList();
  }

  void _openLegalFlow(_LegalType type) {
    switch (type) {
      case _LegalType.privacy:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const _LegalDocumentScreen(
            title: 'Privacy Policy',
            paragraphs: [
              'Spark only stores data needed to run real-time nearby coordination.',
              'Phone login data, spark participation, and safety reports are stored securely.',
              'We do not expose private personal details inside spark cards or chat lists.',
              'Location is used only for discovery, sorting, and relevance.',
            ],
          ),
        ));
      case _LegalType.guidelines:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const _LegalDocumentScreen(
            title: 'Community Guidelines',
            paragraphs: [
              'Create real, time-bound sparks only.',
              'No harassment, abuse, illegal activity, or misleading posts.',
              'Respect participant safety and keep location details accurate.',
              'Repeated violations can lead to account restrictions.',
            ],
          ),
        ));
      case _LegalType.safety:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const _SafetyReportScreen()));
    }
  }

  String _inviteMessage() =>
      'Join me on Spark for real-time plans nearby.\n'
      'Use my invite code $_referralCode while signing up.\n'
      'https://spark.app/invite/$_referralCode';

  Future<void> _shareInvite() async {
    _analytics.track('referral_share_tapped', properties: {'code': _referralCode});
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(1, 1, 1, 1);
    await Share.share(
      _inviteMessage(),
      subject: 'Join me on Spark',
      sharePositionOrigin: shareOrigin,
    );
  }

  Future<void> _copyInviteCode() async {
    await Clipboard.setData(ClipboardData(text: _referralCode));
    _analytics.track('referral_code_copied', properties: {'code': _referralCode});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Invite code copied'),
        duration: Duration(seconds: 2),
        backgroundColor: _kNavy,
      ),
    );
  }

  Future<void> _openEditProfileSheet() async {
    final nameController = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Your name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'name@example.com',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty || !text.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'SAVE CHANGES',
                backgroundColor: _kNavy,
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  setState(() {
                    _name = nameController.text.trim();
                    _email = emailController.text.trim();
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Profile updated'),
                      duration: Duration(seconds: 2),
                      backgroundColor: _kNavy,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.location,
    required this.memberSince,
    required this.createdCount,
    required this.joinedCount,
    required this.onEditTap,
  });

  final String name;
  final String email;
  final String location;
  final String memberSince;
  final int createdCount;
  final int joinedCount;
  final VoidCallback onEditTap;

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'SV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover band
        Container(
          height: 120,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E2E50), Color(0xFF2F426F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Subtle pattern dots
              Positioned(
                right: -10,
                top: -10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              Positioned(
                right: 30,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              // Back button
              Positioned(
                left: 12,
                top: 12,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Edit button
              Positioned(
                right: 12,
                top: 12,
                child: GestureDetector(
                  onTap: onEditTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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

        // White card below cover
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D111827),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Avatar + name area
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            location,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Since $memberSince',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  height: 1,
                  color: AppColors.border,
                ),

                // Stats row
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _StatCell(
                        value: '$createdCount',
                        label: 'Created',
                        icon: Icons.bolt_rounded,
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      _StatCell(
                        value: '$joinedCount',
                        label: 'Joined',
                        icon: Icons.people_outline_rounded,
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      _StatCell(
                        value: '${createdCount + joinedCount}',
                        label: 'Total',
                        icon: Icons.local_fire_department_outlined,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Avatar overlapping cover + card
        Positioned(
          left: 32,
          top: 60,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22111827),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: _kNavy,
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _kNavy),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state card
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Spark Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileRecentItem {
  const _ProfileRecentItem(this.spark, this.tag);
  final Spark spark;
  final String tag;
}

class _RecentSparkCard extends StatelessWidget {
  const _RecentSparkCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
              decoration: BoxDecoration(
                color: _kNavyLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: _kNavy, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kNavyLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kNavy,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Referral Card
// ─────────────────────────────────────────────────────────────────────────────

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({
    required this.referralCode,
    required this.onShare,
    required this.onCopyCode,
  });

  final String referralCode;
  final VoidCallback onShare;
  final VoidCallback onCopyCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E2E50), Color(0xFF3B5490)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite friends to Spark',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Unlock badges, early features & host boost',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Code row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Your code',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          referralCode,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kNavy,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onCopyCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kNavyLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Copy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kNavy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 15),
                    label: const Text(
                      'Share invite link',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alerts Card
// ─────────────────────────────────────────────────────────────────────────────

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.startsSoon,
    required this.fillingFast,
    required this.radiusKm,
    required this.interests,
    required this.onStartsSoonChanged,
    required this.onFillingFastChanged,
    required this.onRadiusChanged,
    required this.onInterestToggle,
  });

  final bool startsSoon;
  final bool fillingFast;
  final int radiusKm;
  final Set<SparkCategory> interests;
  final ValueChanged<bool> onStartsSoonChanged;
  final ValueChanged<bool> onFillingFastChanged;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<SparkCategory> onInterestToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle rows
          _AlertToggleRow(
            icon: Icons.timer_outlined,
            label: 'Starts in 15 min',
            sublabel: 'Alert before a nearby spark begins',
            value: startsSoon,
            onChanged: onStartsSoonChanged,
            isFirst: true,
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
          _AlertToggleRow(
            icon: Icons.people_outline_rounded,
            label: 'Filling fast',
            sublabel: 'Alert when spots are almost gone',
            value: fillingFast,
            onChanged: onFillingFastChanged,
            isFirst: false,
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),

          // Radius
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, size: 15, color: _kNavy),
                    const SizedBox(width: 6),
                    const Text(
                      'Notify radius',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [2, 5, 10]
                      .map(
                        (km) => ChoiceChip(
                          label: Text('$km km'),
                          selected: radiusKm == km,
                          onSelected: (_) => onRadiusChanged(km),
                          selectedColor: _kNavyLight,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: radiusKm == km ? _kNavy : AppColors.textSecondary,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 1, color: AppColors.border),

          // Interests
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.interests_outlined, size: 15, color: _kNavy),
                    const SizedBox(width: 6),
                    const Text(
                      'Interests',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: SparkCategory.values
                      .where((c) => c != SparkCategory.hangout)
                      .map(
                        (category) => FilterChip(
                          selected: interests.contains(category),
                          label: Text(category.label),
                          onSelected: (_) => onInterestToggle(category),
                          selectedColor: _kNavyLight,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: interests.contains(category)
                                ? _kNavy
                                : AppColors.textSecondary,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertToggleRow extends StatelessWidget {
  const _AlertToggleRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    required this.isFirst,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, isFirst ? 14 : 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kNavyLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: _kNavy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _kNavy,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legal Links
// ─────────────────────────────────────────────────────────────────────────────

enum _LegalType { privacy, guidelines, safety }

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({
    required this.onTap,
    required this.onSosTap,
  });

  final void Function(_LegalType type) onTap;
  final VoidCallback onSosTap;

  @override
  Widget build(BuildContext context) {
    const links = <(_LegalType, String, IconData)>[
      (_LegalType.privacy, 'Privacy policy', Icons.lock_outline_rounded),
      (_LegalType.guidelines, 'Community guidelines', Icons.groups_outlined),
      (_LegalType.safety, 'Report a safety issue', Icons.flag_outlined),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SOS button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSosTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.sos_rounded, size: 17),
                label: const Text(
                  'SOS ALERT',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
          // Link rows
          for (final (i, link) in links.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 46, color: AppColors.border),
            InkWell(
              onTap: () => onTap(link.$1),
              borderRadius: i == links.length - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(15))
                  : BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(link.$3, size: 16, color: _kNavy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        link.$2,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legal document screen
// ─────────────────────────────────────────────────────────────────────────────

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.paragraphs,
  });

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paragraphs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              paragraphs[index],
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Safety report screen
// ─────────────────────────────────────────────────────────────────────────────

class _SafetyReportScreen extends StatefulWidget {
  const _SafetyReportScreen();

  @override
  State<_SafetyReportScreen> createState() => _SafetyReportScreenState();
}

class _SafetyReportScreenState extends State<_SafetyReportScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a safety issue')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell us what happened',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Describe the issue briefly',
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'SUBMIT REPORT',
              backgroundColor: _kNavy,
              onPressed: () {
                if (_controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add a short description')),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Safety report submitted')),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
