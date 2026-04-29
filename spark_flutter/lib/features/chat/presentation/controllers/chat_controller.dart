import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/chat_api_repository.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/chat_message.dart' as domain;

final chatApiRepositoryProvider = Provider<ChatApiRepository>((ref) {
  return ChatApiRepository(dio: ref.watch(dioProvider));
});

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.sender,
    required this.text,
    required this.isMine,
    required this.timeLabel,
    required this.createdAt,
    this.isHost = false,
    this.isAi = false,
  });

  final String id;
  final String senderId;
  final String sender;
  final String text;
  final bool isMine;
  final String timeLabel;
  final DateTime createdAt;
  final bool isHost;
  final bool isAi;
}

// Family key: (sparkId, currentUserId)
final chatThreadsProvider = StateNotifierProvider.family<
  ChatThreadNotifier,
  List<ChatMessage>,
  (String, String)
>((ref, params) {
  final (sparkId, currentUserId) = params;
  return ChatThreadNotifier(
    ref.watch(chatApiRepositoryProvider),
    sparkId,
    currentUserId,
  );
});

class ChatThreadNotifier extends StateNotifier<List<ChatMessage>> {
  ChatThreadNotifier(this._repository, this._sparkId, this._currentUserId)
      : super([]) {
    fetchHistory();
  }

  final ChatApiRepository _repository;
  final String _sparkId;
  final String _currentUserId;

  Future<void> fetchHistory() async {
    try {
      final page = await _repository.fetchChatHistory(sparkId: _sparkId);
      // API returns newest-first; reverse so oldest is at top of the list.
      state = page.items.map(_toUiMessage).toList().reversed.toList();
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    try {
      final sent = await _repository.sendMessage(sparkId: _sparkId, text: text);
      state = [...state, _toUiMessage(sent)];
    } catch (_) {}
  }

  ChatMessage _toUiMessage(domain.ChatMessage msg) {
    final isMe = msg.senderId == _currentUserId;
    final senderLabel = isMe
        ? 'You'
        : (msg.senderId.length >= 4
            ? 'User ${msg.senderId.substring(0, 4)}'
            : 'User');
    return ChatMessage(
      id: msg.id,
      senderId: msg.senderId,
      sender: senderLabel,
      text: msg.text,
      isMine: isMe,
      timeLabel: _formatTimestamp(msg.createdAt),
      createdAt: msg.createdAt,
      isAi: msg.isAi,
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final hour =
        dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class ChatModerationState {
  const ChatModerationState({
    this.removedUserIds = const <String>{},
    this.blockedUserIds = const <String>{},
  });

  final Set<String> removedUserIds;
  final Set<String> blockedUserIds;

  ChatModerationState copyWith({
    Set<String>? removedUserIds,
    Set<String>? blockedUserIds,
  }) {
    return ChatModerationState(
      removedUserIds: removedUserIds ?? this.removedUserIds,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }
}

final chatModerationProvider = StateProvider<Map<String, ChatModerationState>>(
  (ref) => {},
);

final lockedSparkIdsProvider = StateProvider<Set<String>>((ref) => <String>{});
