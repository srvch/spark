import 'package:dio/dio.dart';
import '../domain/chat_message.dart';

class ChatApiRepository {
  ChatApiRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<ChatPage> fetchChatHistory({
    required String sparkId,
    int page = 0,
    int size = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/chats/$sparkId',
      queryParameters: {'page': page, 'size': size},
    );
    final data = response.data ?? const {};
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((json) => _fromJson(json as Map<String, dynamic>))
        .toList();
    return ChatPage(
      items: items,
      page: (data['page'] as num?)?.toInt() ?? page,
      hasMore: (data['hasMore'] as bool?) ?? false,
    );
  }

  Future<ChatMessage> sendMessage({
    required String sparkId,
    required String text,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/chats/$sparkId',
      data: {'text': text},
    );
    return _fromJson(response.data ?? const {});
  }

  ChatMessage _fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: '${json['id']}',
      sparkId: '${json['sparkId']}',
      senderId: '${json['senderId']}',
      text: '${json['text']}',
      createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal() ?? DateTime.now(),
      isAi: json['isAi'] == true,
    );
  }
}
