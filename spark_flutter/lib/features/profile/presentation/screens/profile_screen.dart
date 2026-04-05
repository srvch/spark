import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/navigation/root_shell.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/domain/spark_invite.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import '../../../spark/presentation/screens/activity_screen.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/profile_preferences_controller.dart';
import '../../data/safety_api_repository.dart';
import '../widgets/availability_sheet.dart';

const _kNavy = AppColors.accent;
const _kDivider = AppColors.border;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final AnalyticsService _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(sparkDataControllerProvider).refreshInvites();
      ref.read(profileProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final joined = ref.watch(joinedSparksProvider);
    final created = ref.watch(myCreatedSparksProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final pendingInvites = ref
        .watch(sparkInvitesProvider)
        .where((invite) => invite.status == SparkInviteStatus.pending)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => backOrGoDiscover(context, ref),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.accent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.6,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                  profileAsync.when(
                    data: (_) => const SizedBox.shrink(),
                    loading: () => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => IconButton(
                      onPressed: () =>
                          ref.read(profileProvider.notifier).load(),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: AppColors.errorText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.errorText,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Could not load profile.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.errorText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              ref.read(profileProvider.notifier).load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (profile) {
                  final referralCode = _referralCode(profile.userId);
                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            PersonAvatar(
                              name: profile.displayName,
                              radius: 30,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.displayName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                      fontFamily: 'Manrope',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${profile.phoneNumber}  ·  Since ${_monthYear(profile.memberSince)}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.onSurfaceStrong,
                                      fontFamily: 'Manrope',
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  GestureDetector(
                                    onTap: () => _openEditProfileSheet(
                                      profile.displayName,
                                    ),
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
                                const VerticalDivider(
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
                                const VerticalDivider(
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

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ReferralBanner(
                          referralCode: referralCode,
                          onShare: () => _shareInvite(referralCode),
                          onCopyCode: () => _copyInviteCode(referralCode),
                        ),
                      ),

                      const SizedBox(height: 24),

                      _SectionLabel('Activity'),
                      _MenuRow(
                        icon: Icons.bolt_outlined,
                        label: 'Your Sparks',
                        sublabel: created.isEmpty && joined.isEmpty
                            ? 'No activity yet'
                            : '${created.length} created · ${joined.length} joined',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ActivityScreen(),
                          ),
                        ),
                      ),
                      _MenuRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Spark Invites',
                        sublabel: pendingInvites > 0
                            ? '$pendingInvites pending'
                            : 'No pending invites',
                        badge: pendingInvites,
                        onTap: () {
                          ref.read(bottomTabProvider.notifier).state = 2;
                        },
                      ),

                      const _Divider(),
                      _SectionLabel('Preferences'),
                      _MenuRow(
                        icon: Icons.notifications_outlined,
                        label: 'Notification alerts',
                        sublabel: notificationPrefs.notifyStarts15 ||
                                notificationPrefs.notifyStarts60 ||
                                notificationPrefs.notifyFillingFast ||
                                notificationPrefs.notifyJoin ||
                                notificationPrefs.notifyLeaveHost ||
                                notificationPrefs.notifyNewNearby
                            ? 'Alerts on'
                            : 'All alerts off',
                        onTap: () => _showAlertsSheet(context),
                      ),
                      _MenuRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'My Availability',
                        sublabel: AvailabilityHelper.summaryLabel(
                          ref.watch(availabilityProvider),
                        ),
                        onTap: () => showAvailabilitySheet(context),
                      ),

                      const _Divider(),
                      _SectionLabel('Privacy'),
                      _PrivacyToggle(
                        label: 'Hide phone number from others',
                        sublabel: 'Only show first 2 digits and xxxxx on your profile and sparks',
                        value: profile.hidePhoneNumber,
                        onChanged: (val) => ref.read(profileProvider.notifier).toggleHidePhoneNumber(val),
                      ),

                      const _Divider(),
                      _SectionLabel('Safety & Legal'),
                      _MenuRow(
                        icon: Icons.sos_rounded,
                        label: 'SOS Alert',
                        labelColor: AppColors.errorText,
                        iconColor: AppColors.errorText,
                        onTap: () {
                          _analytics.track('sos_from_profile_tapped');
                          _openLegalFlow(_LegalType.safety);
                        },
                      ),
                      _MenuRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacy policy',
                        onTap: () {
                          _analytics.track(
                            'legal_link_opened',
                            properties: {'type': 'privacy'},
                          );
                          _openLegalFlow(_LegalType.privacy);
                        },
                      ),
                      _MenuRow(
                        icon: Icons.groups_outlined,
                        label: 'Community guidelines',
                        isLast: true,
                        onTap: () {
                          _analytics.track(
                            'legal_link_opened',
                            properties: {'type': 'guidelines'},
                          );
                          _openLegalFlow(_LegalType.guidelines);
                        },
                      ),

                      const _Divider(),
                      _SectionLabel('Account'),
                      _MenuRow(
                        icon: Icons.logout_rounded,
                        label: 'Sign out',
                        labelColor: AppColors.errorText,
                        iconColor: AppColors.errorText,
                        isLast: true,
                        onTap: () => _confirmSignOut(context),
                      ),

                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthYear(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return "${months[dt.month - 1]} '${dt.year.toString().substring(2)}";
  }

  String _referralCode(String userId) {
    final short = userId.replaceAll('-', '').substring(0, 6).toUpperCase();
    return 'SPARK$short';
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
              useApi: true,
              paragraphs: [
                'Be respectful and kind to others.',
                'No harassment or illegal content.',
                'Stay safe and meet in public.',
              ],
            ),
          ),
        );
      case _LegalType.safety:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const _LegalDocumentScreen(
              title: 'Safety Tips',
              paragraphs: [
                'Always meet in well-lit public areas.',
                'Verify spark hosts by checking their profiles.',
                'Share your coordination status with a trusted contact.',
                'If you feel uncomfortable, leave and report via SOS.',
              ],
            ),
          ),
        );
    }
  }

  void _openSafetyReport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _SafetyReportScreen()),
    );
  }

  String _inviteMessage(String code) =>
      'Join me on Spark for real-time plans nearby.\n'
      'Use my invite code $code while signing up.\n'
      'https://spark.app/invite/$code';

  Future<void> _shareInvite(String code) async {
    _analytics.track(
      'referral_share_tapped',
      properties: {'code': code},
    );
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(1, 1, 1, 1);
    await Share.share(
      _inviteMessage(code),
      subject: 'Join me on Spark',
      sharePositionOrigin: shareOrigin,
    );
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _analytics.track('referral_code_copied', properties: {'code': code});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: const Text('Invite code copied'),
        duration: const Duration(seconds: 2),
        backgroundColor: _kNavy,
      ),
    );
  }

  Future<void> _openEditProfileSheet(String currentName) async {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'At least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: saving ? 'Saving…' : 'SAVE CHANGES',
                  backgroundColor: _kNavy,
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => saving = true);
                          try {
                            await ref
                                .read(profileProvider.notifier)
                                .updateDisplayName(
                                  nameController.text.trim(),
                                );
                            if (!mounted) return;
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text('Profile updated'),
                                duration: Duration(seconds: 2),
                                backgroundColor: _kNavy,
                              ),
                            );
                          } catch (_) {
                            setModalState(() => saving = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not update profile. Try again.',
                                ),
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Sign out?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Manrope',
          ),
        ),
        content: const Text(
          "You'll need your phone number to sign back in.",
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
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
                color: AppColors.onSurfaceStrong,
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
          color: AppColors.onSurfaceLight,
          letterSpacing: 0.6,
          fontFamily: 'Manrope',
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.sublabel,
    this.labelColor,
    this.iconColor,
    this.isLast = false,
    this.badge = 0,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final Color? labelColor;
  final Color? iconColor;
  final bool isLast;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 12 : 0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? AppColors.iconFg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: labelColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.action,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 24,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2F4D78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Invite & earn',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  fontFamily: 'Manrope',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Share your code and get early access perks when friends join.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCopyCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            referralCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 1.2,
                              fontFamily: 'Manrope',
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.copy_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onShare,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Share',
                    style: TextStyle(
                      color: _kNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertsSheet extends ConsumerWidget {
  const _AlertsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
          const SizedBox(height: 20),
          const Text(
            'SPARKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceLight,
              letterSpacing: 0.8,
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 10),
          _AlertToggle(
            label: 'Starts in 15 min',
            sublabel: 'Alert when a joined spark is about to begin',
            value: prefs.notifyStarts15,
            onChanged: notifier.setNotifyStarts15,
          ),
          const SizedBox(height: 12),
          _AlertToggle(
            label: 'Starts in 60 min',
            sublabel: 'Early reminder for upcoming sparks',
            value: prefs.notifyStarts60,
            onChanged: notifier.setNotifyStarts60,
          ),
          const SizedBox(height: 12),
          _AlertToggle(
            label: 'Filling fast',
            sublabel: 'Alert when a nearby spark has only 1 spot left',
            value: prefs.notifyFillingFast,
            onChanged: notifier.setNotifyFillingFast,
          ),
          const SizedBox(height: 20),
          const Text(
            'SOCIAL & NEARBY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceLight,
              letterSpacing: 0.8,
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 10),
          _AlertToggle(
            label: 'New Sparks nearby',
            sublabel: 'Notify when a new spark is created in your radius',
            value: prefs.notifyNewNearby,
            onChanged: notifier.setNotifyNewNearby,
          ),
          const SizedBox(height: 12),
          _AlertToggle(
            label: 'Someone joined',
            sublabel: 'Alert when a participant joins your spark',
            value: prefs.notifyJoin,
            onChanged: notifier.setNotifyJoin,
          ),
          const SizedBox(height: 12),
          _AlertToggle(
            label: 'Host left',
            sublabel: 'Alert when the host leaves a spark you joined',
            value: prefs.notifyLeaveHost,
            onChanged: notifier.setNotifyLeaveHost,
          ),
        ],
      ),
    );
  }
}

class _AlertToggle extends StatelessWidget {
  const _AlertToggle({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  fontFamily: 'Manrope',
                ),
              ),
              Text(
                sublabel,
                style: const TextStyle(
                  fontSize: 12,
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
    );
  }
}

enum _LegalType { privacy, guidelines, safety }

class _LegalDocumentScreen extends ConsumerWidget {
  const _LegalDocumentScreen({
    required this.title,
    required this.paragraphs,
    this.useApi = false,
  });

  final String title;
  final List<String> paragraphs;
  final bool useApi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: useApi
          ? FutureBuilder<List<String>>(
              future: ref.read(safetyApiRepositoryProvider).fetchGuidelines(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data ?? paragraphs;
                return _buildList(list);
              },
            )
          : _buildList(paragraphs),
    );
  }

  Widget _buildList(List<String> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          items[index],
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SafetyReportScreen extends ConsumerStatefulWidget {
  const _SafetyReportScreen();

  @override
  ConsumerState<_SafetyReportScreen> createState() => _SafetyReportScreenState();
}

class _SafetyReportScreenState extends ConsumerState<_SafetyReportScreen> {
  final _controller = TextEditingController();
  var _submitting = false;

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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: _submitting ? 'Submitting…' : 'SUBMIT REPORT',
              backgroundColor: _kNavy,
              onPressed: _submitting
                  ? null
                  : () async {
                      final note = _controller.text.trim();
                      if (note.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please add a short description'),
                          ),
                        );
                        return;
                      }
                      setState(() => _submitting = true);
                      try {
                        await ref.read(safetyApiRepositoryProvider).triggerSos(
                              sparkId: '00000000-0000-0000-0000-000000000000', // Global
                              locationName: 'Profile Report',
                              note: note,
                            );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Safety report submitted'),
                          ),
                        );
                        Navigator.of(context).pop();
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _submitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sublabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
