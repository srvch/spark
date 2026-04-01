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

const _kNavy = AppColors.accent;
const _kNavyLight = Color(0xFFF0F4FF);
const _kDivider = AppColors.border;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _name = 'Saurav';
  String _email = 'spark@saurav.app';
  final String _memberSince = "Mar '26";
  final String _referralCode = 'SAURAV10';
  final AnalyticsService _analytics = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    final joined = ref.watch(joinedSparksProvider);
    final created = ref.watch(myCreatedSparksProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final recent = _recentItems(created: created, joined: joined);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(999),
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
                    'Account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Profile row ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: _kNavy,
                          child: Text(
                            _initials(_name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Manrope',
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                  fontFamily: 'Manrope',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_email  ·  Since $_memberSince',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                  fontFamily: 'Manrope',
                                ),
                              ),
                              const SizedBox(height: 5),
                              GestureDetector(
                                onTap: _openEditProfileSheet,
                                child: const Text(
                                  'Edit profile →',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _kNavy,
                                    fontFamily: 'Manrope',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Quick stats row ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _kDivider),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            _QuickStat(
                              icon: Icons.bolt_rounded,
                              label: 'Created',
                              value: '${created.length}',
                              isFirst: true,
                            ),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: _kDivider,
                            ),
                            _QuickStat(
                              icon: Icons.people_outline_rounded,
                              label: 'Joined',
                              value: '${joined.length}',
                              isFirst: false,
                            ),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: _kDivider,
                            ),
                            _QuickStat(
                              icon: Icons.local_fire_department_outlined,
                              label: 'Total',
                              value: '${created.length + joined.length}',
                              isFirst: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Referral banner ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ReferralBanner(
                      referralCode: _referralCode,
                      onShare: _shareInvite,
                      onCopyCode: _copyInviteCode,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Menu sections ─────────────────────────────────
                  _SectionLabel('Activity'),
                  _MenuRow(
                    icon: Icons.bolt_outlined,
                    label: 'Your Sparks',
                    sublabel: recent.isEmpty
                        ? 'No activity yet'
                        : '${created.length} created · ${joined.length} joined',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ActivityScreen()),
                    ),
                  ),

                  const _Divider(),
                  _SectionLabel('Preferences'),
                  _MenuRow(
                    icon: Icons.notifications_outlined,
                    label: 'Notification alerts',
                    sublabel: notificationPrefs.notifyStartsSoon ||
                            notificationPrefs.notifyFillingFast
                        ? 'Alerts on'
                        : 'Alerts off',
                    onTap: () => _showAlertsSheet(context),
                  ),

                  const _Divider(),
                  _SectionLabel('Safety & Legal'),
                  _MenuRow(
                    icon: Icons.sos_rounded,
                    label: 'SOS Alert',
                    labelColor: const Color(0xFFB91C1C),
                    iconColor: const Color(0xFFB91C1C),
                    onTap: () {
                      _analytics.track('sos_from_profile_tapped');
                      _openLegalFlow(_LegalType.safety);
                    },
                  ),
                  _MenuRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Privacy policy',
                    onTap: () {
                      _analytics.track('legal_link_opened',
                          properties: {'type': 'privacy'});
                      _openLegalFlow(_LegalType.privacy);
                    },
                  ),
                  _MenuRow(
                    icon: Icons.groups_outlined,
                    label: 'Community guidelines',
                    isLast: true,
                    onTap: () {
                      _analytics.track('legal_link_opened',
                          properties: {'type': 'guidelines'});
                      _openLegalFlow(_LegalType.guidelines);
                    },
                  ),

                  const SizedBox(height: 40),
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

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'SV';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Manrope',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
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
                decoration: const InputDecoration(labelText: 'Email'),
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

  void _showAlertsSheet(BuildContext ctx) {
    final container = ProviderScope.containerOf(ctx);
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: const _AlertsSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick stat cell
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.isFirst,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _kNavy),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black38,
          letterSpacing: 0.6,
          fontFamily: 'Manrope',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu row
// ─────────────────────────────────────────────────────────────────────────────

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.sublabel,
    this.labelColor,
    this.iconColor,
    this.isLast = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final Color? labelColor;
  final Color? iconColor;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? Colors.black54,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: labelColor ?? Colors.black,
                      fontFamily: 'Manrope',
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black45,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin divider
// ─────────────────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 24, thickness: 4, color: Color(0xFFF5F5F7));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Referral banner
// ─────────────────────────────────────────────────────────────────────────────

class _ReferralBanner extends StatelessWidget {
  const _ReferralBanner({
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
        color: const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Large ghost text watermark
          Positioned(
            right: -8,
            top: -4,
            child: Text(
              referralCode,
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: _kNavy.withOpacity(0.06),
                fontFamily: 'Manrope',
                letterSpacing: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kNavy,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'INVITE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                          fontFamily: 'Manrope',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Refer friends, unlock\nhost boost & early access',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    height: 1.35,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 12),
                // Code pill + buttons row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _kNavy.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              referralCode,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
                                letterSpacing: 1.5,
                                fontFamily: 'Manrope',
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: onCopyCode,
                              child: const Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: _kNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onShare,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: _kNavy,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Invite →',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Manrope',
                          ),
                        ),
                      ),
                    ),
                  ],
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
// Alerts sheet (modal)
// ─────────────────────────────────────────────────────────────────────────────

class _AlertsSheet extends ConsumerWidget {
  const _AlertsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification alerts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Control when Spark notifies you',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black45,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 20),

            _SheetToggleRow(
              icon: Icons.timer_outlined,
              label: 'Starts in 15 min',
              value: prefs.notifyStartsSoon,
              onChanged: notifier.setStartsSoon,
            ),
            const Divider(height: 1, color: _kDivider),
            _SheetToggleRow(
              icon: Icons.people_outline_rounded,
              label: 'Filling fast',
              value: prefs.notifyFillingFast,
              onChanged: notifier.setFillingFast,
            ),

            const SizedBox(height: 20),

            const Text(
              'NOTIFY RADIUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 0.6,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [2, 5, 10]
                  .map(
                    (km) => ChoiceChip(
                      label: Text('$km km'),
                      selected: prefs.radiusKm == km,
                      onSelected: (_) => notifier.setRadius(km),
                      selectedColor: _kNavyLight,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: prefs.radiusKm == km ? _kNavy : Colors.black54,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 20),

            const Text(
              'INTERESTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 0.6,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: SparkCategory.values
                  .where((c) => c != SparkCategory.hangout)
                  .map(
                    (category) => FilterChip(
                      selected: prefs.interests.contains(category),
                      label: Text(category.label),
                      onSelected: (_) => notifier.toggleInterest(category),
                      selectedColor: _kNavyLight,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: prefs.interests.contains(category)
                            ? _kNavy
                            : Colors.black54,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetToggleRow extends StatelessWidget {
  const _SheetToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: 'Manrope',
              ),
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
// Legal & Safety
// ─────────────────────────────────────────────────────────────────────────────

enum _LegalType { privacy, guidelines, safety }

class _ProfileRecentItem {
  const _ProfileRecentItem(this.spark, this.tag);
  final Spark spark;
  final String tag;
}

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
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            paragraphs[index],
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'Manrope',
              ),
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
                    const SnackBar(
                        content: Text('Please add a short description')),
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
