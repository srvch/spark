package com.spark.backend.controller;

import com.spark.backend.entity.SparkEventEntity;
import com.spark.backend.repository.AppUserRepository;
import com.spark.backend.service.SparkService;
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

@RestController
@RequestMapping("/api/v1/sparks")
public class SparkController {
    private final SparkService sparkService;
    private final AppUserRepository appUserRepository;

    public SparkController(SparkService sparkService, AppUserRepository appUserRepository) {
        this.sparkService = sparkService;
        this.appUserRepository = appUserRepository;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SparkResponse create(Authentication authentication, @Valid @RequestBody CreateSparkRequest req) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
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
                        req.maxSpots()
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
            @RequestParam double lat,
            @RequestParam double lng,
            @RequestParam(defaultValue = "5") @DecimalMin("0.1") @DecimalMax("50") double radiusKm,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size
    ) {
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
                        item.hostUserId()
                ))
                .toList();
        return new NearbyPageResponse(items, page, size, nearbyPage.hasMore());
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
                spark.getStatus().name(),
                spark.getCreatedAt(),
                spark.getUpdatedAt()
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
            @Min(1) @Max(1000) int maxSpots
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
            String status,
            Instant createdAt,
            Instant updatedAt
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
            String hostUserId
    ) {
    }

    public record NearbyPageResponse(
            List<NearbySparkResponse> items,
            int page,
            int size,
            boolean hasMore
    ) {
    }
}
