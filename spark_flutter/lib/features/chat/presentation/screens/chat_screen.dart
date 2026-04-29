import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../spark/domain/spark.dart';
import '../../../spark/presentation/controllers/spark_controller.dart';
import '../controllers/chat_controller.dart';

// ── Design tokens (light-theme chat) ─────────────────────────────────────────
// App background = white; this screen uses a subtle warm-gray chat canvas
// (exact same pattern as WhatsApp/Telegram on iOS).
const _kChatBg      = Color(0xFFF0F2F5); // subtle gray chat canvas
const _kOwnBubble   = Color(0xFF1E3A5F); // brand navy – own messages
const _kOtherBubble = Colors.white;       // incoming messages
const _kInputBg     = Colors.white;       // input bar
const _kFieldBg     = Color(0xFFF7F8FC); // text field pill
const _kSendActive  = Color(0xFF1E3A5F); // send button when field has text
const _kDatePill    = Color(0xE6E6E6E6); // date separator pill
const _kNavy        = Color(0xFF1E3A5F); // app bar icons / title
const _kDivider     = Color(0xFFE4E7EC); // subtle dividers

// ── Per-user sender name palette ──────────────────────────────────────────────
const _kSenderPalette = <Color>[
  Color(0xFF1D4ED8), // indigo
  Color(0xFF059669), // emerald
  Color(0xFFB45309), // amber
  Color(0xFF7C3AED), // violet
  Color(0xFF0E7490), // cyan
  Color(0xFFBE185D), // pink
];

// ── Quick replies ──────────────────────────────────────────────────────────────
const _kQuickReplies = <String>[
  'Reaching in 5 min 👋',
  'At the location ✅',
  'Running 10 min late 🙏',
  'Please share exact spot 📍',
];

// ─────────────────────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.spark});
  final Spark spark;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Participant builder ────────────────────────────────────────────────────
  List<_ChatUser> _buildParticipants({
    required Spark spark,
    required String currentUserId,
    required String currentUserName,
    required List<ChatMessage> thread,
    required List<String> participantIds,
  }) {
    final map = <String, _ChatUser>{};
    map[spark.createdBy] = _ChatUser(
      id: spark.createdBy,
      name: spark.createdBy == currentUserId
          ? currentUserName
          : 'Spark host',
      isHost: true,
    );
    if (!map.containsKey(currentUserId)) {
      map[currentUserId] = _ChatUser(
        id: currentUserId,
        name: currentUserName,
        isHost: spark.createdBy == currentUserId,
      );
    }
    for (final id in participantIds) {
      if (!map.containsKey(id)) {
        map[id] = _ChatUser(id: id, name: 'User ${id.substring(0, 4)}');
      }
    }
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final currentUserName =
        ref.watch(authSessionProvider)?.displayName.trim().isNotEmpty == true
            ? ref.watch(authSessionProvider)!.displayName
            : 'You';

    final isHost = widget.spark.createdBy == currentUserId;
    final isLocked =
        ref.watch(lockedSparkIdsProvider).contains(widget.spark.id);

    final moderationMap = ref.watch(chatModerationProvider);
    final moderation =
        moderationMap[widget.spark.id] ?? const ChatModerationState();
    final hiddenIds = {
      ...moderation.blockedUserIds,
      ...moderation.removedUserIds,
    };

    final thread = ref.watch(
        chatThreadsProvider((widget.spark.id, currentUserId)));

    // Scroll to bottom when history first arrives
    ref.listen(chatThreadsProvider((widget.spark.id, currentUserId)),
        (prev, next) {
      if ((prev == null || prev.isEmpty) && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });

    final messages =
        thread.where((m) => !hiddenIds.contains(m.senderId)).toList();

    final participantIds =
        ref.watch(sparkParticipantsProvider(widget.spark.id));
    final participants = _buildParticipants(
      spark: widget.spark,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      thread: thread,
      participantIds: participantIds,
    );
    final visibleCount =
        participants.where((p) => !hiddenIds.contains(p.id)).length;

    return Scaffold(
      backgroundColor: AppColors.background,

      // ── App bar ─────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
        titleSpacing: 2,
        title: Row(
          children: [
            // Category badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _categoryBgColor(widget.spark.category),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _categoryEmoji(widget.spark.category),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
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
                            fontSize: 15,
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
                            color: AppColors.pillSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Locked',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedIcon,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '$visibleCount ${visibleCount == 1 ? 'person' : 'people'} · ${widget.spark.timeLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
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
                  const Icon(Icons.shield_outlined,
                      color: _kNavy, size: 21),
                  if (isLocked)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316),
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
          child: Container(height: 1, color: AppColors.cardDivider),
        ),
      ),

      // ── Body ──────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Locked banner
          if (isLocked)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              color: AppColors.pillSurface,
              child: Row(
                children: const [
                  Icon(Icons.lock_rounded,
                      size: 13, color: AppColors.mutedIcon),
                  SizedBox(width: 8),
                  Text(
                    'This spark is locked — no new members can join',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedIcon,
                    ),
                  ),
                ],
              ),
            ),

          // Message list
          Expanded(
            child: Container(
              color: _kChatBg,
              child: messages.isEmpty
                  ? _EmptyState(spark: widget.spark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      itemCount: _buildItems(messages).length,
                      itemBuilder: (context, index) {
                        final item = _buildItems(messages)[index];
                        if (item is _DateSeparatorItem) {
                          return _DateSeparatorWidget(label: item.label);
                        }
                        final entry = item as _MessageItem;
                        return _MessageBubble(
                          message: entry.message,
                          showSender: entry.showSender,
                          isLast: entry.isLast,
                          senderColor:
                              _senderColor(entry.message.senderId),
                        );
                      },
                    ),
            ),
          ),

          // Quick reply chips
          Container(
            height: 44,
            color: _kInputBg,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              scrollDirection: Axis.horizontal,
              itemCount: _kQuickReplies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final text = _kQuickReplies[i];
                return GestureDetector(
                  onTap: () {
                    _inputController.text = text;
                    _sendMessage(currentUserId, currentUserName);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDim,
                      border: Border.all(color: _kDivider),
                      borderRadius: BorderRadius.circular(20),
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

          // Divider before input
          Container(height: 1, color: AppColors.cardDivider),

          // Input bar
          Container(
            color: _kInputBg,
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 16),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Text field
                  Expanded(
                    child: Container(
                      constraints:
                          const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: _kFieldBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _kDivider),
                      ),
                      child: TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: null,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Message…',
                          hintStyle: TextStyle(
                            fontSize: 14.5,
                            color: AppColors.textMuted,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Animated mic / send button
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _inputController,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: hasText
                            ? () => _sendMessage(
                                currentUserId, currentUserName)
                            : null,
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: hasText
                                ? _kSendActive
                                : AppColors.pillSurface,
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration:
                                const Duration(milliseconds: 150),
                            child: Icon(
                              hasText
                                  ? Icons.send_rounded
                                  : Icons.mic_none_rounded,
                              key: ValueKey(hasText),
                              color: hasText
                                  ? Colors.white
                                  : AppColors.mutedIcon,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _senderColor(String senderId) {
    final hash = senderId.codeUnits.fold(0, (a, b) => a + b);
    return _kSenderPalette[hash % _kSenderPalette.length];
  }

  static String _categoryEmoji(SparkCategory? cat) {
    return switch (cat) {
      SparkCategory.sports  => '⚽',
      SparkCategory.study   => '📚',
      SparkCategory.ride    => '🛵',
      SparkCategory.events  => '🎉',
      SparkCategory.hangout => '☕',
      _                     => '⚡',
    };
  }

  static Color _categoryBgColor(SparkCategory? cat) {
    return switch (cat) {
      SparkCategory.sports  => AppColors.catSports,
      SparkCategory.study   => AppColors.catStudy,
      SparkCategory.ride    => AppColors.catRide,
      SparkCategory.events  => AppColors.catEvents,
      SparkCategory.hangout => AppColors.catHangout,
      _                     => AppColors.accentSurface,
    };
  }

  List<Object> _buildItems(List<ChatMessage> messages) {
    final items = <Object>[];
    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final prev = i > 0 ? messages[i - 1] : null;
      if (prev == null || !_sameDay(prev.createdAt, msg.createdAt)) {
        items.add(_DateSeparatorItem(_dateLabel(msg.createdAt)));
      }
      final showSender =
          i == 0 || messages[i - 1].senderId != msg.senderId;
      final isLast = i == messages.length - 1 ||
          messages[i + 1].senderId != msg.senderId;
      items.add(
          _MessageItem(msg, showSender: showSender, isLast: isLast));
    }
    return items;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  void _sendMessage(String currentUserId, String currentUserName) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    ref
        .read(chatThreadsProvider((widget.spark.id, currentUserId))
            .notifier)
        .sendMessage(text);

    ref.read(analyticsServiceProvider).track(
      'chat_message_sent',
      properties: {
        'spark_id': widget.spark.id,
        'length': text.length,
      },
    );

    _inputController.clear();
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

  // ── Host controls ─────────────────────────────────────────────────────────
  Future<void> _openHostControls(
    BuildContext context,
    List<_ChatUser> users,
    ChatModerationState moderation,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final locked = ref
                .read(lockedSparkIdsProvider)
                .contains(widget.spark.id);
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
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.accentSurface,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: const Icon(
                              Icons.shield_outlined,
                              color: _kNavy,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
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
                              'Manage participants & settings',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Lock toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDim,
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: locked
                                  ? AppColors.pillSurface
                                  : AppColors.accentSurface,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Icon(
                              locked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 18,
                              color: locked
                                  ? AppColors.mutedIcon
                                  : _kNavy,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
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
                                      : 'Stop new members joining',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
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
                        'PARTICIPANTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mutedIcon,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...members.map((user) {
                        final removed = moderation
                            .removedUserIds
                            .contains(user.id);
                        final blocked = moderation
                            .blockedUserIds
                            .contains(user.id);
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
                      }),
                    ] else ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDim,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.cardBorder),
                        ),
                        child: const Text(
                          'No participants yet. They appear once they join.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
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
        content: Text(lock
            ? 'Spark locked — no new joins allowed'
            : 'Spark unlocked — anyone can join'),
      ),
    );
  }

  void _removeUser(String userId) {
    final map = {...ref.read(chatModerationProvider)};
    final current =
        map[widget.spark.id] ?? const ChatModerationState();
    map[widget.spark.id] = current.copyWith(
      removedUserIds: {...current.removedUserIds, userId},
    );
    ref.read(chatModerationProvider.notifier).state = map;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Participant removed from this spark')),
    );
  }

  void _blockUser(String userId) {
    final map = {...ref.read(chatModerationProvider)};
    final current =
        map[widget.spark.id] ?? const ChatModerationState();
    map[widget.spark.id] = current.copyWith(
      blockedUserIds: {...current.blockedUserIds, userId},
    );
    ref.read(chatModerationProvider.notifier).state = map;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Participant blocked')),
    );
  }
}

// ── Data types ────────────────────────────────────────────────────────────────

class _ChatUser {
  const _ChatUser(
      {required this.id,
      required this.name,
      this.isHost = false});
  final String id;
  final String name;
  final bool isHost;
}

class _DateSeparatorItem {
  const _DateSeparatorItem(this.label);
  final String label;
}

class _MessageItem {
  const _MessageItem(this.message,
      {required this.showSender, required this.isLast});
  final ChatMessage message;
  final bool showSender;
  final bool isLast;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.spark});
  final Spark spark;

  static String _emoji(SparkCategory? cat) => switch (cat) {
    SparkCategory.sports  => '⚽',
    SparkCategory.study   => '📚',
    SparkCategory.ride    => '🛵',
    SparkCategory.events  => '🎉',
    SparkCategory.hangout => '☕',
    _                     => '⚡',
  };

  static Color _bgColor(SparkCategory? cat) => switch (cat) {
    SparkCategory.sports  => AppColors.catSports,
    SparkCategory.study   => AppColors.catStudy,
    SparkCategory.ride    => AppColors.catRide,
    SparkCategory.events  => AppColors.catEvents,
    SparkCategory.hangout => AppColors.catHangout,
    _                     => AppColors.accentSurface,
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _bgColor(spark.category),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                _emoji(spark.category),
                style: const TextStyle(fontSize: 38),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              spark.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kNavy,
                fontFamily: 'Manrope',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Be the first to say hi! 👋',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date separator pill ───────────────────────────────────────────────────────

class _DateSeparatorWidget extends StatelessWidget {
  const _DateSeparatorWidget({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _kDatePill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showSender,
    required this.isLast,
    required this.senderColor,
  });

  final ChatMessage message;
  final bool showSender;
  final bool isLast;
  final Color senderColor;

  @override
  Widget build(BuildContext context) {
    if (message.isAi) return _buildAiBubble();
    if (message.isMine) return _buildOwnBubble();
    return _buildOtherBubble();
  }

  // Own message — right side, navy bubble ─────────────────────────────────
  Widget _buildOwnBubble() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 10 : 2,
        left: 72,
        right: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
            decoration: BoxDecoration(
              color: _kOwnBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: const Radius.circular(18),
                // WhatsApp-style tail
                bottomRight: Radius.circular(isLast ? 4 : 18),
              ),
            ),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.timeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.done_all_rounded,
                        size: 13,
                        color:
                            Colors.white.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Incoming message — left side, white bubble ─────────────────────────────
  Widget _buildOtherBubble() {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 10 : 2,
        right: 72,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar: only on last bubble in a group
          SizedBox(
            width: 32,
            child: isLast ? _Avatar(name: message.sender) : null,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: 3, left: 4),
                    child: Text(
                      message.isHost
                          ? '${message.sender} · Host'
                          : message.sender,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: senderColor,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(14, 9, 14, 8),
                  decoration: BoxDecoration(
                    color: _kOtherBubble,
                    borderRadius: BorderRadius.only(
                      // WhatsApp-style tail on incoming
                      topLeft: Radius.circular(isLast ? 4 : 18),
                      topRight: const Radius.circular(18),
                      bottomLeft: const Radius.circular(18),
                      bottomRight: const Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          message.timeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
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

  // AI message — centered card ─────────────────────────────────────────────
  Widget _buildAiBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 8, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                const Color(0xFF1E3A5F).withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF1E3A5F)
                    .withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 13, color: _kNavy),
                  const SizedBox(width: 6),
                  Text(
                    message.sender,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                      fontFamily: 'Manrope',
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                message.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.timeLabel,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
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
        color: AppColors.avatarBg,
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
      return s.isEmpty ? '?' : s[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kNavy,
                    fontFamily: 'Manrope',
                  ),
                ),
                if (user.isHost)
                  const Text(
                    'Host',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (removed || blocked)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pillSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                removed ? 'Removed' : 'Blocked',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedIcon,
                ),
              ),
            )
          else ...[
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pillSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedIcon,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onBlock,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Block',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.errorText,
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
