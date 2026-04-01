import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import '../controllers/chat_controller.dart';

final _kNavy = AppColors.accent;
const _kNavyLight = Color(0xFFEAF0FF);
const _kSurface = Color(0xFFF7F8FC);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.spark});
  final Spark spark;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _quickReplies = <String>[
    'Reaching in 5 min 👋',
    'At the location ✅',
    'Running 10 min late 🙏',
    'Please share exact spot 📍',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Participant building ──────────────────────────────────────────────────
  // Merges spark.participants + chat thread senders so host controls
  // always has a populated list even on a freshly created spark.
  List<_ChatUser> _buildParticipants({
    required Spark spark,
    required String currentUserId,
    required String currentUserName,
    required List<ChatMessage> thread,
  }) {
    final map = <String, _ChatUser>{};

    // Always include the host
    map[spark.createdBy] = _ChatUser(
      id: spark.createdBy,
      name: spark.createdBy == currentUserId ? currentUserName : 'Spark host',
      isHost: true,
    );

    // Current user
    if (!map.containsKey(currentUserId)) {
      map[currentUserId] = _ChatUser(
        id: currentUserId,
        name: currentUserName,
        isHost: spark.createdBy == currentUserId,
      );
    }

    // Participants from spark model
    for (var i = 0; i < spark.participants.length; i++) {
      final id = 'p_$i';
      if (!map.containsKey(id)) {
        map[id] = _ChatUser(
          id: id,
          name: _nameFromInitial(spark.participants[i], i),
        );
      }
    }

    // Participants from chat thread (catches senders not in spark.participants)
    for (final msg in thread) {
      if (!map.containsKey(msg.senderId)) {
        map[msg.senderId] = _ChatUser(
          id: msg.senderId,
          name: msg.sender,
          isHost: msg.isHost,
        );
      }
    }

    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final currentUserName =
        ref.watch(authSessionProvider)?.displayName.trim().isNotEmpty == true
        ? ref.watch(authSessionProvider)!.displayName
        : 'You';
    final isHost = widget.spark.createdBy == currentUserId;
    final isLocked = ref.watch(lockedSparkIdsProvider)
        .contains(widget.spark.id);

    final moderationMap = ref.watch(chatModerationProvider);
    final moderation =
        moderationMap[widget.spark.id] ?? const ChatModerationState();
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

    final participants = _buildParticipants(
      spark: widget.spark,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      thread: thread,
    );
    final visibleCount =
        participants.where((p) => !hiddenUserIds.contains(p.id)).length;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _kNavy,
          ),
        ),
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.spark.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                      fontFamily: 'Manrope',
                    ),
                  ),
                ),
                if (isLocked) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              '$visibleCount people · ${widget.spark.timeLabel}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        actions: [
          if (isHost)
            IconButton(
              tooltip: 'Host controls',
              onPressed: () =>
                  _openHostControls(context, participants, moderation),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.shield_outlined, color: _kNavy, size: 20),
                  if (isLocked)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6B7280),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F1F5)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Locked banner ─────────────────────────────────────────
            if (isLocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                color: const Color(0xFFF5F5F7),
                child: Row(
                  children: const [
                    Icon(Icons.lock_rounded,
                        size: 14, color: Color(0xFF6B7280)),
                    SizedBox(width: 6),
                    Text(
                      'This spark is locked — no new members can join',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Message list ──────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final showSender = index == 0 ||
                      messages[index - 1].senderId != message.senderId;
                  final isLast = index == messages.length - 1 ||
                      messages[index + 1].senderId != message.senderId;
                  return _MessageBubble(
                    message: message,
                    showSender: showSender,
                    isLast: isLast,
                  );
                },
              ),
            ),
            // ── Quick replies ─────────────────────────────────────────
            Container(
              height: 38,
              color: Colors.white,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _quickReplies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final text = _quickReplies[index];
                  return GestureDetector(
                    onTap: () {
                      _controller.text = text;
                      _sendMessage(currentUserId, currentUserName);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border:
                            Border.all(color: const Color(0xFFDDE1ED)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kNavy,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // ── Input bar ─────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: const Color(0xFFE4E7EF)),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) =>
                            _sendMessage(currentUserId, currentUserName),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Message the group…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFB0B7C3),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        _sendMessage(currentUserId, currentUserName),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: _kNavy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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

  // ── Message helpers ───────────────────────────────────────────────────────

  List<ChatMessage> _initialMessages({
    required Spark spark,
    required String currentUserId,
    required String currentUserName,
  }) {
    final hostName =
        spark.createdBy == currentUserId ? currentUserName : 'Spark host';
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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final map = {...ref.read(chatThreadsProvider)};
    final current = [
      ...(map[widget.spark.id] ??
          _initialMessages(
            spark: widget.spark,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
          ))
    ];
    current.add(ChatMessage(
      senderId: currentUserId,
      sender: currentUserName,
      text: text,
      isMine: true,
      timeLabel: _formatNow(),
      isHost: widget.spark.createdBy == currentUserId,
    ));
    map[widget.spark.id] = current;
    ref.read(chatThreadsProvider.notifier).state = map;
    ref.read(analyticsServiceProvider).track(
      'chat_message_sent',
      properties: {'spark_id': widget.spark.id, 'length': text.length},
    );
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Host controls sheet ───────────────────────────────────────────────────

  Future<void> _openHostControls(
    BuildContext context,
    List<_ChatUser> users,
    ChatModerationState moderation,
  ) async {
    final isLocked =
        ref.read(lockedSparkIdsProvider).contains(widget.spark.id);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final locked =
                ref.read(lockedSparkIdsProvider).contains(widget.spark.id);
            final members = users
                .where((u) => u.id != widget.spark.createdBy)
                .toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _kNavyLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.shield_outlined,
                              color: _kNavy, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Host controls',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
                                fontFamily: 'Manrope',
                              ),
                            ),
                            Text(
                              'Manage participants & spark settings',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── SPARK-403: Lock/close spark ────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: locked
                                  ? const Color(0xFFF5F5F7)
                                  : _kNavyLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              locked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 18,
                              color: locked
                                  ? const Color(0xFF6B7280)
                                  : _kNavy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locked
                                      ? 'Spark is locked'
                                      : 'Lock spark',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _kNavy,
                                    fontFamily: 'Manrope',
                                  ),
                                ),
                                Text(
                                  locked
                                      ? 'No new members can join'
                                      : 'Stop new members from joining',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: locked,
                            activeColor: _kNavy,
                            onChanged: (val) {
                              _toggleLock(val);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),

                    if (members.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Participants',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...members.map(
                        (user) {
                          final removed =
                              moderation.removedUserIds.contains(user.id);
                          final blocked =
                              moderation.blockedUserIds.contains(user.id);
                          return _HostControlRow(
                            user: user,
                            removed: removed,
                            blocked: blocked,
                            onRemove: () {
                              _removeUser(user.id);
                              Navigator.of(ctx).pop();
                            },
                            onBlock: () {
                              _blockUser(user.id);
                              Navigator.of(ctx).pop();
                            },
                          );
                        },
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'No participants yet. They will appear here once they join.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleLock(bool lock) {
    final current = {...ref.read(lockedSparkIdsProvider)};
    if (lock) {
      current.add(widget.spark.id);
    } else {
      current.remove(widget.spark.id);
    }
    ref.read(lockedSparkIdsProvider.notifier).state = current;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lock
              ? 'Spark locked — no new joins allowed'
              : 'Spark unlocked — anyone can join',
        ),
      ),
    );
  }

  // ── SPARK-401: Remove ─────────────────────────────────────────────────────
  void _removeUser(String userId) {
    final map = {...ref.read(chatModerationProvider)};
    final current = map[widget.spark.id] ?? const ChatModerationState();
    map[widget.spark.id] = current.copyWith(
      removedUserIds: {...current.removedUserIds, userId},
    );
    ref.read(chatModerationProvider.notifier).state = map;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Participant removed from this spark')),
    );
  }

  // ── SPARK-402: Block ──────────────────────────────────────────────────────
  void _blockUser(String userId) {
    final map = {...ref.read(chatModerationProvider)};
    final current = map[widget.spark.id] ?? const ChatModerationState();
    map[widget.spark.id] = current.copyWith(
      blockedUserIds: {...current.blockedUserIds, userId},
    );
    ref.read(chatModerationProvider.notifier).state = map;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Participant blocked')),
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

// ── Data types ────────────────────────────────────────────────────────────────

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

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showSender,
    required this.isLast,
  });

  final ChatMessage message;
  final bool showSender;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    if (message.isMine) {
      return Padding(
        padding: EdgeInsets.only(bottom: isLast ? 10 : 3, left: 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showSender)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 2),
                child: Text(
                  message.isHost ? 'You · Host' : 'You',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kNavy,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: Radius.circular(isLast ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message.timeLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 10 : 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isLast)
            _Avatar(name: message.sender)
          else
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    child: Text(
                      message.isHost
                          ? '${message.sender} · Host'
                          : message.sender,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isLast ? 4 : 18),
                      topRight: const Radius.circular(18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A202C),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message.timeLabel,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 64),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: _kNavyLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(name),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _kNavy,
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final s = parts.first;
      return s.isEmpty ? '?' : s.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

// ── Host control row ──────────────────────────────────────────────────────────

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          _Avatar(name: user.name),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kNavy,
                fontFamily: 'Manrope',
              ),
            ),
          ),
          if (removed || blocked)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                removed ? 'Removed' : 'Blocked',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            )
          else ...[
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onBlock,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Block',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
