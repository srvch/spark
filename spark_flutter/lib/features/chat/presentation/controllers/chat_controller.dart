import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  const ChatMessage({
    required this.senderId,
    required this.sender,
    required this.text,
    required this.isMine,
    required this.timeLabel,
    this.isHost = false,
  });

  final String senderId;
  final String sender;
  final String text;
  final bool isMine;
  final String timeLabel;
  final bool isHost;
}

final chatThreadsProvider =
    StateProvider<Map<String, List<ChatMessage>>>((ref) => {});

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
