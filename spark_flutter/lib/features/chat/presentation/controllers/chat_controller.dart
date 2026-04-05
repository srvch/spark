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
    this.isHost = false,
    this.isAi = false,
  });

  final String id;
  final String senderId;
  final String sender;
  final String text;
  final bool isMine;
  final String timeLabel;
  final bool isHost;
  final bool isAi;
}

final chatThreadsProvider =
    StateNotifierProvider.family<ChatThreadNotifier, List<ChatMessage>, String>((ref, sparkId) {
  return ChatThreadNotifier(ref.watch(chatApiRepositoryProvider), sparkId);
});

class ChatThreadNotifier extends StateNotifier<List<ChatMessage>> {
  ChatThreadNotifier(this._repository, this._sparkId) : super([]) {
    fetchHistory();
  }

  final ChatApiRepository _repository;
  final String _sparkId;

  Future<void> fetchHistory() async {
    try {
      final page = await _repository.fetchChatHistory(sparkId: _sparkId);
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
    return ChatMessage(
      id: msg.id,
      senderId: msg.senderId,
      sender: msg.isAi ? 'Spark Bot' : 'User ${msg.senderId.substring(0, 4)}',
      text: msg.text,
      isMine: false, // In production, check against current user ID
      timeLabel: '${msg.createdAt.hour}:${msg.createdAt.minute}',
      isAi: msg.isAi,
    );
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

final chatModerationProvider =
    StateProvider<Map<String, ChatModerationState>>((ref) => {});

final lockedSparkIdsProvider =
    StateProvider<Set<String>>((ref) => <String>{});
