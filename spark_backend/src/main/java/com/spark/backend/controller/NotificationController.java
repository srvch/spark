package com.spark.backend.controller;

import com.spark.backend.entity.NotificationPreferenceEntity;
import com.spark.backend.entity.UserNotificationEntity;
import com.spark.backend.security.CurrentUser;
import com.spark.backend.service.NotificationService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/notifications")
public class NotificationController {
    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public List<NotificationResponse> list(
            Authentication authentication,
            @RequestParam(defaultValue = "false") boolean unreadOnly
    ) {
        String userId = ((CurrentUser) authentication.getPrincipal()).userId();
        return notificationService.listForUser(userId, unreadOnly).stream()
                .map(this::toResponse)
                .toList();
    }

    @PostMapping("/{notificationId}/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void markRead(Authentication authentication, @PathVariable UUID notificationId) {
        String userId = ((CurrentUser) authentication.getPrincipal()).userId();
        notificationService.markRead(userId, notificationId);
    }

    @GetMapping("/preferences")
    public PreferencesResponse getPreferences(Authentication authentication) {
        String userId = ((CurrentUser) authentication.getPrincipal()).userId();
        return toPreferencesResponse(notificationService.getPreferences(userId));
    }

    @PutMapping("/preferences")
    public PreferencesResponse updatePreferences(
            Authentication authentication,
            @Valid @RequestBody PreferencesRequest request
    ) {
        String userId = ((CurrentUser) authentication.getPrincipal()).userId();
        var saved = notificationService.upsertPreferences(
                userId,
                new NotificationService.PreferencesUpdate(
                        request.notifyJoin(),
                        request.notifyLeaveHost(),
                        request.notifyFillingFast(),
                        request.notifyStarts15(),
                        request.notifyStarts60(),
                        request.notifyNewNearby(),
                        request.interestCategories(),
                        request.radiusKm()
                )
        );
        return toPreferencesResponse(saved);
    }

    @ExceptionHandler({IllegalArgumentException.class, IllegalStateException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> badRequest(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    private NotificationResponse toResponse(UserNotificationEntity n) {
        return new NotificationResponse(
                n.getId(),
                n.getType().name(),
                n.getSparkId(),
                n.getActorUserId(),
                n.getTitle(),
                n.getBody(),
                n.getBatchCount(),
                n.getCreatedAt(),
                n.getReadAt()
        );
    }

    private PreferencesResponse toPreferencesResponse(NotificationPreferenceEntity p) {
        return new PreferencesResponse(
                p.isNotifyJoin(),
                p.isNotifyLeaveHost(),
                p.isNotifyFillingFast(),
                p.isNotifyStarts15(),
                p.isNotifyStarts60(),
                p.isNotifyNewNearby(),
                p.getInterestCategories(),
                p.getRadiusKm()
        );
    }

    public record NotificationResponse(
            UUID id,
            String type,
            UUID sparkId,
            String actorUserId,
            String title,
            String body,
            int batchCount,
            Instant createdAt,
            Instant readAt
    ) {
    }

    public record PreferencesRequest(
            boolean notifyJoin,
            boolean notifyLeaveHost,
            boolean notifyFillingFast,
            boolean notifyStarts15,
            boolean notifyStarts60,
            boolean notifyNewNearby,
            @NotBlank String interestCategories,
            @Min(1) @Max(50) int radiusKm
    ) {
    }

    public record PreferencesResponse(
            boolean notifyJoin,
            boolean notifyLeaveHost,
            boolean notifyFillingFast,
            boolean notifyStarts15,
            boolean notifyStarts60,
            boolean notifyNewNearby,
            String interestCategories,
            int radiusKm
    ) {
    }
}
