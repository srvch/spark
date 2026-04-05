class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sparkId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.isMine = false,
    this.isAi = false,
  });

  final String id;
  final String sparkId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final bool isMine;
  final bool isAi;
}

class ChatPage {
  const ChatPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<ChatMessage> items;
  final int page;
  final bool hasMore;
}
