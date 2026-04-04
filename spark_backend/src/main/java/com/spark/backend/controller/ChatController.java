package com.spark.backend.controller;

import com.spark.backend.entity.ChatMessageEntity;
import com.spark.backend.security.CurrentUser;
import com.spark.backend.service.ChatService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/chats")
public class ChatController {
    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @PostMapping("/{sparkId}")
    @ResponseStatus(HttpStatus.CREATED)
    public ChatMessageResponse sendMessage(
            Authentication authentication,
            @PathVariable UUID sparkId,
            @Valid @RequestBody SendMessageRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        ChatMessageEntity saved = chatService.sendMessage(sparkId, currentUser.userId(), request.text());
        return toResponse(saved);
    }

    @GetMapping("/{sparkId}")
    public ChatPageResponse getHistory(
            @PathVariable UUID sparkId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        Page<ChatMessageEntity> msgPage = chatService.getChatHistory(sparkId, page, size);
        List<ChatMessageResponse> items = msgPage.getContent().stream()
                .map(this::toResponse)
                .toList();
        return new ChatPageResponse(items, msgPage.getNumber(), msgPage.getSize(), msgPage.hasNext());
    }

    private ChatMessageResponse toResponse(ChatMessageEntity entity) {
        return new ChatMessageResponse(
                entity.getId(),
                entity.getSparkId(),
                entity.getSenderId(),
                entity.getText(),
                entity.getCreatedAt()
        );
    }

    public record SendMessageRequest(
            @NotBlank @Size(max = 1000) String text
    ) {}

    public record ChatMessageResponse(
            UUID id,
            UUID sparkId,
            String senderId,
            String text,
            Instant createdAt
    ) {}

    public record ChatPageResponse(
            List<ChatMessageResponse> items,
            int page,
            int size,
            boolean hasMore
    ) {}
}
