import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import '../controllers/chat_controller.dart';

const _bannerBlue = Color(0xFF2F426F);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.spark});
  final Spark spark;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  static const _quickReplies = <String>[
    'Reaching in 5 min',
    'At the location',
    'Running 10 min late',
    'Please share exact spot',
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final currentUserName =
        ref.watch(authSessionProvider)?.displayName.trim().isNotEmpty == true
        ? ref.watch(authSessionProvider)!.displayName
        : 'You';
    final isHost = widget.spark.createdBy == currentUserId;

    final participants = _buildParticipants(
      spark: widget.spark,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
    );
    final moderationMap = ref.watch(chatModerationProvider);
    final moderation = moderationMap[widget.spark.id] ?? const ChatModerationState();
    final hiddenUserIds = {
      ...moderation.blockedUserIds,
      ...moderation.removedUserIds,
    };

    final allThreads = ref.watch(chatThreadsProvider);
    final initial = _initialMessages(
      spark: widget.spark,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
    );
    final thread = allThreads[widget.spark.id] ?? initial;
    final messages = thread
        .where((msg) => !hiddenUserIds.contains(msg.senderId))
        .toList();
    final availableParticipants = participants
        .where((p) => !hiddenUserIds.contains(p.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.spark.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text(
              '${availableParticipants.length} people · ${isHost ? 'Host controls on' : 'Participant'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (isHost)
            IconButton(
              tooltip: 'Manage participants',
              onPressed: () => _openHostControls(context, participants, moderation),
              icon: const Icon(Icons.shield_outlined, color: Color(0xFF2F426F)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final showSender = index == 0 ||
                      messages[index - 1].senderId != message.senderId;
                  return _MessageRow(message: message, showSender: showSender);
                },
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final text = _quickReplies[index];
                  return ActionChip(
                    label: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () {
                      controller.text = text;
                      _sendMessage(currentUserId, currentUserName);
                    },
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: _quickReplies.length,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(currentUserId, currentUserName),
                      decoration: const InputDecoration(hintText: 'Message'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: PrimaryButton(
                      label: 'SEND',
                      compact: true,
                      backgroundColor: _bannerBlue,
                      onPressed: () => _sendMessage(currentUserId, currentUserName),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ChatUser> _buildParticipants({
    required Spark spark,
    required String currentUserId,
    required String currentUserName,
  }) {
    final host = _ChatUser(
      id: spark.createdBy,
      name: spark.createdBy == currentUserId ? 'You' : 'Spark host',
      isHost: true,
    );
    final me = _ChatUser(id: currentUserId, name: currentUserName, isHost: spark.createdBy == currentUserId);
    final others = <_ChatUser>[
      for (var i = 0; i < spark.participants.length; i++)
        _ChatUser(
          id: 'p_$i',
          name: _nameFromInitial(spark.participants[i], i),
        ),
    ];
    final map = <String, _ChatUser>{};
    for (final user in [host, me, ...others]) {
      map[user.id] = user;
    }
    return map.values.toList();
  }

  List<ChatMessage> _initialMessages({
    required Spark spark,
    required String currentUserId,
    required String currentUserName,
  }) {
    final hostName = spark.createdBy == currentUserId ? 'You' : 'Spark host';
    return [
      ChatMessage(
        senderId: spark.createdBy,
        sender: hostName,
        text: 'I am at the location.',
        isMine: spark.createdBy == currentUserId,
        timeLabel: '6:12 PM',
        isHost: true,
      ),
      ChatMessage(
        senderId: currentUserId,
        sender: currentUserName,
        text: 'Running 10 min late',
        isMine: true,
        timeLabel: '6:13 PM',
        isHost: spark.createdBy == currentUserId,
      ),
      ChatMessage(
        senderId: 'p_1',
        sender: _nameFromInitial('SN', 1),
        text: 'Got it. Reaching in 5.',
        isMine: false,
        timeLabel: '6:14 PM',
      ),
    ];
  }

  void _sendMessage(String currentUserId, String currentUserName) {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final map = {...ref.read(chatThreadsProvider)};
    final current = [...(map[widget.spark.id] ?? _initialMessages(
      spark: widget.spark,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
    ))];
    current.add(
      ChatMessage(
        senderId: currentUserId,
        sender: currentUserName,
        text: text,
        isMine: true,
        timeLabel: _formatNow(),
        isHost: widget.spark.createdBy == currentUserId,
      ),
    );
    map[widget.spark.id] = current;
    ref.read(chatThreadsProvider.notifier).state = map;
    ref.read(analyticsServiceProvider).track(
      'chat_message_sent',
      properties: {
        'spark_id': widget.spark.id,
        'length': text.length,
      },
    );
    controller.clear();
  }

  Future<void> _openHostControls(
    BuildContext context,
    List<_ChatUser> users,
    ChatModerationState moderation,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final members = users.where((u) => !u.isHost).toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Host controls',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Remove or block participants for this spark chat.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...members.map(
                  (user) => _HostControlRow(
                    user: user,
                    removed: moderation.removedUserIds.contains(user.id),
                    blocked: moderation.blockedUserIds.contains(user.id),
                    onRemove: () => _removeUser(user.id),
                    onBlock: () => _blockUser(user.id),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeUser(String userId) {
    final map = {...ref.read(chatModerationProvider)};
    final current = map[widget.spark.id] ?? const ChatModerationState();
    map[widget.spark.id] = current.copyWith(
      removedUserIds: {...current.removedUserIds, userId},
    );
    ref.read(chatModerationProvider.notifier).state = map;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Participant removed from this spark')),
    );
  }

  void _blockUser(String userId) {
    final map = {...ref.read(chatModerationProvider)};
    final current = map[widget.spark.id] ?? const ChatModerationState();
    map[widget.spark.id] = current.copyWith(
      blockedUserIds: {...current.blockedUserIds, userId},
    );
    ref.read(chatModerationProvider.notifier).state = map;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Participant blocked for this spark')),
    );
  }

  String _formatNow() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final min = now.minute.toString().padLeft(2, '0');
    final suffix = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $suffix';
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
}

class _ChatUser {
  const _ChatUser({
    required this.id,
    required this.name,
    this.isHost = false,
  });

  final String id;
  final String name;
  final bool isHost;
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.showSender});

  final ChatMessage message;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    if (message.isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          margin: const EdgeInsets.only(bottom: 10, left: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _bannerBlue.withValues(alpha: 0.12),
            border: Border.all(color: _bannerBlue.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showSender)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.isHost ? 'You • Host' : 'You',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              Text(
                message.text,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.timeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InitialAvatar(name: message.sender),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Text(
                      message.isHost ? '${message.sender} • Host' : message.sender,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.timeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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

class _HostControlRow extends StatelessWidget {
  const _HostControlRow({
    required this.user,
    required this.removed,
    required this.blocked,
    required this.onRemove,
    required this.onBlock,
  });

  final _ChatUser user;
  final bool removed;
  final bool blocked;
  final VoidCallback onRemove;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _InitialAvatar(name: user.name),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (removed || blocked)
            Text(
              removed ? 'Removed' : 'Blocked',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: removed ? const Color(0xFFB45309) : const Color(0xFFB91C1C),
              ),
            )
          else ...[
            TextButton(
              onPressed: onRemove,
              child: const Text(
                'Remove',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            TextButton(
              onPressed: onBlock,
              child: const Text(
                'Block',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      child: Text(
        _toInitials(name),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  String _toInitials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final single = parts.first;
      return single.isEmpty ? '?' : single.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
