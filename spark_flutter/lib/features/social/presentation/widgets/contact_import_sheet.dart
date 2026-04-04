import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/person_avatar.dart';
import '../../domain/social.dart';
import '../controllers/social_controller.dart';

Future<void> showContactImportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ContactImportSheet(),
  );
}

class ContactImportSheet extends ConsumerStatefulWidget {
  const ContactImportSheet({super.key});

  @override
  ConsumerState<ContactImportSheet> createState() => _ContactImportSheetState();
}

class _ContactImportSheetState extends ConsumerState<ContactImportSheet> {
  final _phoneCtrl = TextEditingController();
  bool _scanning = false;
  bool _checking = false;
  List<MatchedContact>? _results;
  List<Contact> _allContacts = [];
  String? _error;
  final _sending = <String>{};
  final _sent = <String>{};

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanContacts() async {
    setState(() { _scanning = true; _error = null; _results = null; });
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        setState(() {
          _error = 'Contacts access denied. Please allow it in Settings.';
          _scanning = false;
        });
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      _allContacts = contacts;
      final phones = contacts
          .expand((c) => c.phones)
          .map((p) => p.number.replaceAll(RegExp(r'[\s\-\(\)\.]+'), ''))
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      if (phones.isEmpty) {
        setState(() { _error = 'No phone numbers found in your contacts.'; _scanning = false; });
        return;
      }
      final matches = await ref.read(socialApiRepositoryProvider).matchContacts(phones);
      HapticFeedback.lightImpact();
      setState(() { _results = matches; _scanning = false; });
    } catch (e) {
      setState(() { _error = 'Something went wrong. Try again.'; _scanning = false; });
    }
  }

  Future<void> _checkSingle() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() { _checking = true; _error = null; _results = null; });
    try {
      final matches = await ref.read(socialApiRepositoryProvider).matchContacts([raw]);
      HapticFeedback.lightImpact();
      setState(() { _results = matches; _checking = false; });
    } catch (_) {
      setState(() { _error = 'Something went wrong. Try again.'; _checking = false; });
    }
  }

  Future<void> _addFriend(MatchedContact contact) async {
    if (_sending.contains(contact.userId)) return;
    setState(() => _sending.add(contact.userId));
    try {
      await ref.read(socialControllerProvider).sendFriendRequest(contact.phoneNumber);
      HapticFeedback.lightImpact();
      setState(() { _sent.add(contact.userId); _sending.remove(contact.userId); });
    } catch (_) {
      setState(() => _sending.remove(contact.userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send request. Try again.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final friendIds = friends.map((f) => f.userId).toSet();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 14, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D1D6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const Text('Find contacts on Spark',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF000000),
                      fontFamily: 'Manrope',
                      letterSpacing: -0.3)),
              const SizedBox(height: 4),
              const Text(
                'See which of your contacts are already on Spark.',
                style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93), height: 1.4),
              ),
              const SizedBox(height: 22),

              // ── Option 1: device contacts ──────────────────────────────────
              GestureDetector(
                onTap: _scanning ? null : _scanContacts,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.person_2_fill,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _scanning ? 'Scanning contacts…' : 'Import from contacts',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Manrope',
                              ),
                            ),
                            const Text(
                              'Automatically check all your contacts',
                              style: TextStyle(fontSize: 12.5, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      if (_scanning)
                        const CupertinoActivityIndicator(color: Colors.white)
                      else
                        const Icon(CupertinoIcons.chevron_right,
                            color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Divider ────────────────────────────────────────────────────
              Row(children: [
                const Expanded(child: Divider(color: Color(0xFFE5E5EA))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('OR', style: TextStyle(
                      fontSize: 12, color: Color(0xFF8E8E93),
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
                const Expanded(child: Divider(color: Color(0xFFE5E5EA))),
              ]),

              const SizedBox(height: 18),

              // ── Option 2: single number ────────────────────────────────────
              const Text('Check a specific number',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF000000),
                      fontFamily: 'Manrope')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: '+91 98765 43210',
                          hintStyle: TextStyle(color: Color(0xFFC7C7CC), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          prefixIcon: Icon(CupertinoIcons.phone,
                              size: 16, color: Color(0xFF8E8E93)),
                        ),
                        onSubmitted: (_) => _checkSingle(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _checking ? null : _checkSingle,
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _checking
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Text('Find',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    fontFamily: 'Manrope')),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Error ──────────────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(CupertinoIcons.exclamationmark_circle,
                        size: 15, color: Color(0xFFFF3B30)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFFF3B30))),
                    ),
                  ]),
                ),
              ],

              // ── Results ────────────────────────────────────────────────────
              if (_results != null) ...[
                const SizedBox(height: 22),
                if (_results!.isNotEmpty) ...[
                  const Text(
                    'ON SPARK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: List.generate(_results!.length, (i) {
                        final c = _results![i];
                        final isFriend = friendIds.contains(c.userId);
                        final isSent = _sent.contains(c.userId);
                        final isSending = _sending.contains(c.userId);
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 11),
                              child: Row(children: [
                                PersonAvatar(name: c.displayName, radius: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.displayName,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Manrope')),
                                      Text(c.phoneNumber,
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF8E8E93))),
                                    ],
                                  ),
                                ),
                                if (isFriend)
                                  _StatusChip(text: 'Friends', color: Colors.green)
                                else if (isSent)
                                  _StatusChip(text: 'Sent', color: Colors.grey)
                                else
                                  GestureDetector(
                                    onTap: () => _addFriend(c),
                                    child: _ActionBtn(
                                      label: 'Add',
                                      loading: isSending,
                                    ),
                                  ),
                              ]),
                            ),
                            if (i < _results!.length - 1)
                              const Divider(
                                  height: 1, thickness: 0.5,
                                  indent: 58, color: Color(0xFFE5E5EA)),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_allContacts.isNotEmpty) ...[
                  const Text(
                    'INVITE TO SPARK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8E8E93),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Builder(builder: (context) {
                      final matchedPhones = _results!.map((r) => r.phoneNumber).toSet();
                      final others = _allContacts.where((local) {
                        return local.phones.isNotEmpty &&
                            !matchedPhones.contains(
                                local.phones.first.number.replaceAll(RegExp(r'[\s\-()]+'), ''));
                      }).toList();

                      if (others.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'All contacts are already on Spark!',
                              style: TextStyle(fontSize: 13, color: Color(0xFF898989)),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: List.generate(others.length, (i) {
                          final c = others[i];
                          final phone = c.phones.first.number;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                child: Row(children: [
                                  PersonAvatar(name: c.displayName, radius: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.displayName,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'Manrope')),
                                        Text(phone,
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF8E8E93))),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _inviteSms(c.displayName, phone),
                                    child: const _ActionBtn(label: 'Invite'),
                                  ),
                                ]),
                              ),
                              if (i < others.length - 1)
                                const Divider(
                                    height: 1, thickness: 0.5,
                                    indent: 58, color: Color(0xFFE5E5EA)),
                            ],
                          );
                        }),
                      );
                    }),
                  ),
                ],
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _inviteSms(String name, String phone) async {
    final message = 'Hey $name, join me on Spark! It helps me plan meetups with friends easily. Get it here: https://spark.app';
    HapticFeedback.lightImpact();
    await Share.share(message, subject: 'Spark App Invite');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
      );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, this.loading = false});
  final String label;
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.accent, borderRadius: BorderRadius.circular(99)),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CupertinoActivityIndicator(color: Colors.white, radius: 7))
            : Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Manrope')),
      );
}
