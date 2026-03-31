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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _name = 'Saurav';
  String _email = 'spark@saurav.app';
  final String _referralCode = 'SAURAV10';
  final AnalyticsService _analytics = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    final joined = ref.watch(joinedSparksProvider);
    final created = ref.watch(myCreatedSparksProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final recent = _recentItems(created: created, joined: joined);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF2F426F),
                                child: Text(
                                  _initials(_name),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name,
                                      style: const TextStyle(
                                        fontSize: 31,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _email,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Tiny plans. Real people. Right now.',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            label: 'Created',
                            value: '${created.length}',
                            icon: Icons.bolt_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            label: 'Joined',
                            value: '${joined.length}',
                            icon: Icons.people_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _StatInfoBar(
                      createdCount: created.length,
                      joinedCount: joined.length,
                    ),
                    const SizedBox(height: 10),
                    _ReferralCard(
                      referralCode: _referralCode,
                      onShare: _shareInvite,
                      onCopyCode: _copyInviteCode,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Your Sparks',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ActivityScreen()),
                            );
                          },
                          child: const Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2F426F),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Recent joined or created sparks',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (recent.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'No sparks yet. Join or create a spark to see activity here.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...recent.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _RecentSparkCard(
                            title: item.spark.title,
                            subtitle: '${item.spark.timeLabel} · ${item.spark.location}',
                            tag: item.tag,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SparkDetailScreen(spark: item.spark),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _NotificationPrefs(
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
                    const SizedBox(height: 6),
                    const Text(
                      'Reminder preferences are available for on-device testing now.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _LegalLinks(
                      onSosTap: () {
                        _analytics.track('sos_from_profile_tapped');
                        _openLegalFlow(_LegalType.safety);
                      },
                      onTap: (type) {
                        _analytics.track('legal_link_opened', properties: {'type': type.name});
                        _openLegalFlow(type);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'EDIT PROFILE',
                backgroundColor: const Color(0xFF2F426F),
                onPressed: _openEditProfileSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ProfileRecentItem> _recentItems({
    required List<Spark> created,
    required List<Spark> joined,
  }) {
    final createdMapped = created.map((spark) => _ProfileRecentItem(spark, 'Created'));
    final createdIds = created.map((e) => e.id).toSet();
    final joinedMapped = joined
        .where((spark) => !createdIds.contains(spark.id))
        .map((spark) => _ProfileRecentItem(spark, 'Joined'));
    return [...createdMapped, ...joinedMapped].take(3).toList();
  }

  void _openLegalFlow(_LegalType type) {
    switch (type) {
      case _LegalType.privacy:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _LegalDocumentScreen(
              title: 'Privacy Policy',
              paragraphs: [
                'Spark only stores data needed to run real-time nearby coordination.',
                'Phone login data, spark participation, and safety reports are stored securely.',
                'We do not expose private personal details inside spark cards or chat lists.',
                'Location is used only for discovery, sorting, and relevance.',
              ],
            ),
          ),
        );
      case _LegalType.guidelines:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _LegalDocumentScreen(
              title: 'Community Guidelines',
              paragraphs: [
                'Create real, time-bound sparks only.',
                'No harassment, abuse, illegal activity, or misleading posts.',
                'Respect participant safety and keep location details accurate.',
                'Repeated violations can lead to account restrictions.',
              ],
            ),
          ),
        );
      case _LegalType.safety:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const _SafetyReportScreen()),
        );
    }
  }

  String _inviteMessage() {
    return 'Join me on Spark for real-time plans nearby.\n'
        'Use my invite code $_referralCode while signing up.\n'
        'https://spark.app/invite/$_referralCode';
  }

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
        backgroundColor: Color(0xFF2F426F),
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
          MediaQuery.of(context).viewInsets.bottom + 16,
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 10),
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
              const SizedBox(height: 14),
              PrimaryButton(
                label: 'SAVE CHANGES',
                backgroundColor: const Color(0xFF2F426F),
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  setState(() {
                    _name = nameController.text.trim();
                    _email = emailController.text.trim();
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: const Text('Profile updated'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: const Color(0xFF2F426F),
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

enum _LegalType { privacy, guidelines, safety }

class _ProfileRecentItem {
  const _ProfileRecentItem(this.spark, this.tag);
  final Spark spark;
  final String tag;
}

class _NotificationPrefs extends StatelessWidget {
  const _NotificationPrefs({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification interests',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SparkCategory.values
                .where((c) => c != SparkCategory.hangout)
                .map(
                  (category) => FilterChip(
                    selected: interests.contains(category),
                    label: Text(category.label),
                    onSelected: (_) => onInterestToggle(category),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          const Text(
            'Notify radius',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
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
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Notify: starts in 15 min',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: startsSoon,
                onChanged: onStartsSoonChanged,
                activeThumbColor: const Color(0xFF2F426F),
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Notify: filling fast',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: fillingFast,
                onChanged: onFillingFastChanged,
                activeThumbColor: const Color(0xFF2F426F),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Refer Spark',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Grow trusted circles: unlock profile badge, early features, and host boost.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Text(
                  'Code',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    referralCode,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: onCopyCode,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2F426F),
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Copy',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text(
                'Share invite',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2F426F),
                side: const BorderSide(color: Color(0xFF2F426F)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({
    required this.onTap,
    required this.onSosTap,
  });

  final void Function(_LegalType type) onTap;
  final VoidCallback onSosTap;

  @override
  Widget build(BuildContext context) {
    const links = <(_LegalType, String)>[
      (_LegalType.privacy, 'Privacy policy'),
      (_LegalType.guidelines, 'Community guidelines'),
      (_LegalType.safety, 'Report a safety issue'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safety & legal',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SizedBox(
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
              icon: const Icon(Icons.sos_rounded, size: 18),
              label: const Text(
                'SOS ALERT',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final link in links)
            InkWell(
              onTap: () => onTap(link.$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      link.$2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatInfoBar extends StatelessWidget {
  const _StatInfoBar({
    required this.createdCount,
    required this.joinedCount,
  });

  final int createdCount;
  final int joinedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_outlined, size: 16, color: Color(0xFF2F426F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$createdCount created · $joinedCount joined',
              style: const TextStyle(
                fontSize: 12.5,
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D111827),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2F426F)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE7EDF9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF2F426F), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
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
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tag,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2F426F),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
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
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              paragraphs[index],
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
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
              backgroundColor: const Color(0xFF2F426F),
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
