package com.spark.backend.controller;

import com.spark.backend.domain.SparkInviteStatus;
import com.spark.backend.domain.SparkVisibility;
import com.spark.backend.entity.SparkEventEntity;
import com.spark.backend.entity.SparkInviteEntity;
import com.spark.backend.repository.AppUserRepository;
import com.spark.backend.service.SparkService;
import com.spark.backend.service.UserLocationService;
import com.spark.backend.security.CurrentUser;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.core.Authentication;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/v1/sparks")
public class SparkController {
    private final SparkService sparkService;
    private final AppUserRepository appUserRepository;
    private final UserLocationService userLocationService;

    public SparkController(SparkService sparkService,
                           AppUserRepository appUserRepository,
                           UserLocationService userLocationService) {
        this.sparkService = sparkService;
        this.appUserRepository = appUserRepository;
        this.userLocationService = userLocationService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SparkResponse create(Authentication authentication, @Valid @RequestBody CreateSparkRequest req) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        SparkVisibility visibility = req.visibility() == null ? SparkVisibility.PUBLIC : req.visibility();
        List<UUID> circleIds = req.circleIds() == null
                ? List.of()
                : req.circleIds().stream().filter(id -> id != null).distinct().toList();
        List<String> inviteUserIds = req.inviteUserIds() == null
                ? List.of()
                : req.inviteUserIds().stream()
                .filter(id -> id != null && !id.isBlank())
                .map(String::trim)
                .distinct()
                .collect(Collectors.toList());
        validateAudience(visibility, circleIds, inviteUserIds);

        SparkEventEntity spark = sparkService.createSpark(
                new SparkService.CreateSparkCommand(
                        currentUser.userId(),
                        req.category(),
                        req.title(),
                        req.note(),
                        req.locationName(),
                        req.latitude(),
                        req.longitude(),
                        req.startsAt(),
                        req.endsAt(),
                        req.maxSpots(),
                        visibility,
                        circleIds,
                        inviteUserIds,
                        req.recurrenceType(),
                        req.recurrenceDayOfWeek(),
                        req.recurrenceTime(),
                        req.recurrenceEndDate()
                )
        );
        return toResponse(spark, sparkService.joinedCount(spark.getId()), currentUser.userId());
    }

    @GetMapping("/{sparkId}")
    public SparkResponse getOne(Authentication authentication, @PathVariable UUID sparkId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        SparkEventEntity spark = sparkService.getSpark(sparkId);
        return toResponse(spark, sparkService.joinedCount(sparkId), currentUser.userId());
    }

    @GetMapping("/nearby")
    public NearbyPageResponse nearby(
            Authentication authentication,
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(defaultValue = "5") @DecimalMin("0.1") @DecimalMax("50") double radiusKm,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size
    ) {
        // Cache user's location for proactive nearby alerts
        if (authentication != null && authentication.getPrincipal() instanceof CurrentUser currentUser) {
            userLocationService.updateLocation(currentUser.userId(), lat, lng);
        }

        var nearbyPage = sparkService.nearby(lat, lng, radiusKm, page, size);
        var items = nearbyPage.items()
                .stream()
                .map(item -> new NearbySparkResponse(
                        item.id(),
                        item.title(),
                        item.category(),
                        item.locationName(),
                        item.startsAt(),
                        item.maxSpots(),
                        item.joinedCount(),
                        item.maxSpots() - item.joinedCount(),
                        item.distanceKm(),
                        item.hostUserId(),
                        item.visibility()
                ))
                .toList();
        return new NearbyPageResponse(items, page, size, nearbyPage.hasMore());
    }

    /** Public (no auth) endpoint — returns minimal spark info for deep link previews. */
    @GetMapping("/{sparkId}/public")
    public SparkPublicPreview getPublic(@PathVariable UUID sparkId) {
        SparkEventEntity spark = sparkService.getSpark(sparkId);
        long joined = sparkService.joinedCount(sparkId);
        return new SparkPublicPreview(
                spark.getId(),
                spark.getTitle(),
                spark.getCategory(),
                spark.getLocationName(),
                spark.getStartsAt(),
                spark.getMaxSpots(),
                (int) joined,
                spark.getStatus().name()
        );
    }

    @GetMapping("/invites")
    public InviteInboxPageResponse invites(
            Authentication authentication,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var inbox = sparkService.listInvitesForUser(currentUser.userId(), currentUser.phoneNumber(), page, size);
        var items = inbox.items().stream()
                .map(item -> new InviteInboxItemResponse(
                        item.inviteId(),
                        item.sparkId(),
                        item.fromUserId(),
                        item.recipientType(),
                        item.recipientValue(),
                        item.inviteStatus(),
                        item.invitedAt(),
                        item.actedAt(),
                        item.title(),
                        item.category(),
                        item.locationName(),
                        item.startsAt(),
                        item.sparkStatus()
                ))
                .toList();
        return new InviteInboxPageResponse(items, page, size, inbox.hasMore());
    }

    @PostMapping("/{sparkId}/join")
    public SparkResponse join(Authentication authentication, @PathVariable UUID sparkId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        SparkEventEntity spark = sparkService.joinSpark(sparkId, currentUser.userId());
        return toResponse(spark, sparkService.joinedCount(sparkId), currentUser.userId());
    }

    @PostMapping("/{sparkId}/leave")
    public SparkResponse leave(Authentication authentication, @PathVariable UUID sparkId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        SparkEventEntity spark = sparkService.leaveSpark(sparkId, currentUser.userId());
        return toResponse(spark, sparkService.joinedCount(sparkId), currentUser.userId());
    }

    @DeleteMapping("/{sparkId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(Authentication authentication, @PathVariable UUID sparkId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        sparkService.cancelSpark(sparkId, currentUser.userId());
    }

    @PutMapping("/{sparkId}")
    public SparkResponse update(
            Authentication authentication,
            @PathVariable UUID sparkId,
            @Valid @RequestBody CreateSparkRequest req
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        SparkVisibility visibility = req.visibility() == null ? SparkVisibility.PUBLIC : req.visibility();
        List<UUID> circleIds = req.circleIds() == null
                ? List.of()
                : req.circleIds().stream().filter(id -> id != null).distinct().toList();
        List<String> inviteUserIds = req.inviteUserIds() == null
                ? List.of()
                : req.inviteUserIds().stream()
                .filter(id -> id != null && !id.isBlank())
                .map(String::trim)
                .distinct()
                .collect(Collectors.toList());
        validateAudience(visibility, circleIds, inviteUserIds);

        SparkEventEntity spark = sparkService.updateSpark(
                new SparkService.UpdateSparkCommand(
                        sparkId,
                        currentUser.userId(),
                        req.category(),
                        req.title(),
                        req.note(),
                        req.locationName(),
                        req.latitude(),
                        req.longitude(),
                        req.startsAt(),
                        req.endsAt(),
                        req.maxSpots(),
                        visibility,
                        circleIds,
                        inviteUserIds,
                        req.recurrenceType(),
                        req.recurrenceDayOfWeek(),
                        req.recurrenceTime(),
                        req.recurrenceEndDate()
                )
        );
        return toResponse(spark, sparkService.joinedCount(spark.getId()), currentUser.userId());
    }

    @GetMapping("/{sparkId}/participants")
    public List<String> participants(@PathVariable UUID sparkId) {
        return sparkService.listParticipants(sparkId);
    }

    @PostMapping("/{sparkId}/invite/{inviteId}/respond")
    public InviteRespondResponse respondToInvite(
            Authentication authentication,
            @PathVariable UUID sparkId,
            @PathVariable UUID inviteId,
            @Valid @RequestBody InviteRespondRequest req
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        SparkInviteStatus next = req.status();
        if (next == SparkInviteStatus.PENDING) {
            throw new IllegalArgumentException("Status must be IN, MAYBE, or DECLINED.");
        }
        SparkInviteEntity updated = sparkService.respondToInvite(
                sparkId,
                inviteId,
                currentUser.userId(),
                currentUser.phoneNumber(),
                next
        );
        return new InviteRespondResponse(
                updated.getId(),
                updated.getSparkId(),
                updated.getStatus().name(),
                updated.getActedAt(),
                updated.getUpdatedAt()
        );
    }

    @ExceptionHandler({EntityNotFoundException.class})
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public Map<String, String> notFound(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    @ExceptionHandler({IllegalArgumentException.class, IllegalStateException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> badRequest(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    private void validateAudience(
            SparkVisibility visibility,
            List<UUID> circleIds,
            List<String> inviteUserIds
    ) {
        switch (visibility) {
            case PUBLIC -> {
                if (!circleIds.isEmpty() || !inviteUserIds.isEmpty()) {
                    throw new IllegalArgumentException("Public sparks cannot have circleIds or inviteUserIds.");
                }
            }
            case CIRCLE -> {
                if (circleIds.isEmpty()) {
                    throw new IllegalArgumentException("Circle visibility requires at least one circleId.");
                }
                if (!inviteUserIds.isEmpty()) {
                    throw new IllegalArgumentException("Circle visibility does not support inviteUserIds.");
                }
            }
            case INVITE -> {
                if (inviteUserIds.isEmpty()) {
                    throw new IllegalArgumentException("Invite visibility requires at least one inviteUserId.");
                }
                if (!circleIds.isEmpty()) {
                    throw new IllegalArgumentException("Invite visibility does not support circleIds.");
                }
            }
        }
    }

    private SparkResponse toResponse(SparkEventEntity spark, long joinedCount, String requesterUserId) {
        String hostPhoneNumber = null;
        boolean isHost = spark.getHostUserId().equals(requesterUserId);
        boolean isJoined = sparkService.isJoined(spark.getId(), requesterUserId);
        if (isHost || isJoined) {
            try {
                hostPhoneNumber = appUserRepository.findById(UUID.fromString(spark.getHostUserId()))
                        .map(user -> user.getPhoneNumber())
                        .orElse(null);
            } catch (Exception ignored) {
                hostPhoneNumber = null;
            }
        }
        return new SparkResponse(
                spark.getId(),
                spark.getHostUserId(),
                hostPhoneNumber,
                spark.getCategory(),
                spark.getTitle(),
                spark.getNote(),
                spark.getLocationName(),
                spark.getLatitude(),
                spark.getLongitude(),
                spark.getStartsAt(),
                spark.getEndsAt(),
                spark.getMaxSpots(),
                joinedCount,
                Math.max(spark.getMaxSpots() - (int) joinedCount, 0),
                spark.getVisibility().name(),
                spark.getStatus().name(),
                spark.getCreatedAt(),
                spark.getUpdatedAt(),
                "spark://sparks/" + spark.getId(),
                spark.getRecurrenceType(),
                spark.getTemplateId()
        );
    }

    public record CreateSparkRequest(
            @NotBlank String category,
            @NotBlank @Size(max = 180) String title,
            @Size(max = 300) String note,
            @NotBlank String locationName,
            @DecimalMin(value = "-90.0") @DecimalMax(value = "90.0") double latitude,
            @DecimalMin(value = "-180.0") @DecimalMax(value = "180.0") double longitude,
            @NotNull Instant startsAt,
            Instant endsAt,
            @Min(1) @Max(1000) int maxSpots,
            SparkVisibility visibility,
            @Size(max = 100) List<UUID> circleIds,
            @Size(max = 500) List<@NotBlank String> inviteUserIds,
            String recurrenceType,
            Integer recurrenceDayOfWeek,
            String recurrenceTime,
            java.time.LocalDate recurrenceEndDate
    ) {
    }

    public record SparkResponse(
            UUID id,
            String hostUserId,
            String hostPhoneNumber,
            String category,
            String title,
            String note,
            String locationName,
            double latitude,
            double longitude,
            Instant startsAt,
            Instant endsAt,
            int maxSpots,
            long joinedCount,
            int spotsLeft,
            String visibility,
            String status,
            Instant createdAt,
            Instant updatedAt,
            String shareUrl,
            String recurrenceType,
            UUID templateId
    ) {
    }

    public record SparkPublicPreview(
            UUID id,
            String title,
            String category,
            String locationName,
            Instant startsAt,
            int maxSpots,
            int joinedCount,
            String status
    ) {
    }

    public record NearbySparkResponse(
            UUID id,
            String title,
            String category,
            String locationName,
            Instant startsAt,
            int maxSpots,
            int joinedCount,
            int spotsLeft,
            double distanceKm,
            String hostUserId,
            String visibility
    ) {
    }

    public record NearbyPageResponse(
            List<NearbySparkResponse> items,
            int page,
            int size,
            boolean hasMore
    ) {
    }

    public record InviteInboxItemResponse(
            UUID inviteId,
            UUID sparkId,
            String fromUserId,
            String recipientType,
            String recipientValue,
            String inviteStatus,
            Instant invitedAt,
            Instant actedAt,
            String title,
            String category,
            String locationName,
            Instant startsAt,
            String sparkStatus
    ) {
    }

    public record InviteInboxPageResponse(
            List<InviteInboxItemResponse> items,
            int page,
            int size,
            boolean hasMore
    ) {
    }

    public record InviteRespondRequest(
            @NotNull SparkInviteStatus status
    ) {
    }

    public record InviteRespondResponse(
            UUID inviteId,
            UUID sparkId,
            String status,
            Instant actedAt,
            Instant updatedAt
    ) {
    }
}
