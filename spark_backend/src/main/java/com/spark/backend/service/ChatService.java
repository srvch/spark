package com.spark.backend.service;

import com.spark.backend.entity.ChatMessageEntity;
import com.spark.backend.repository.ChatRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class ChatService {
    private final ChatRepository chatRepository;

    public ChatService(ChatRepository chatRepository) {
        this.chatRepository = chatRepository;
    }

    @Transactional
    public ChatMessageEntity sendMessage(UUID sparkId, String senderId, String text) {
        ChatMessageEntity message = new ChatMessageEntity();
        message.setSparkId(sparkId);
        message.setSenderId(senderId);
        message.setText(text);
        return chatRepository.save(message);
    }

    public Page<ChatMessageEntity> getChatHistory(UUID sparkId, int page, int size) {
        return chatRepository.findBySparkIdOrderByCreatedAtDesc(sparkId, PageRequest.of(page, size));
    }
}
