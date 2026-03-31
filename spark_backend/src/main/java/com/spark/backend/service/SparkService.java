package com.spark.backend.service;

import com.spark.backend.domain.ParticipantStatus;
import com.spark.backend.domain.SparkStatus;
import com.spark.backend.entity.SparkEventEntity;
import com.spark.backend.entity.SparkParticipantEntity;
import com.spark.backend.repository.SparkEventRepository;
import com.spark.backend.repository.SparkParticipantRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.transaction.Transactional;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class SparkService {
    private final SparkEventRepository sparkEventRepository;
    private final SparkParticipantRepository sparkParticipantRepository;
    private final LiveSparkCacheService liveSparkCacheService;
    private final NotificationService notificationService;
    private final AiModerationService aiModerationService;

    public SparkService(
            SparkEventRepository sparkEventRepository,
            SparkParticipantRepository sparkParticipantRepository,
            LiveSparkCacheService liveSparkCacheService,
            NotificationService notificationService,
            AiModerationService aiModerationService
    ) {
        this.sparkEventRepository = sparkEventRepository;
        this.sparkParticipantRepository = sparkParticipantRepository;
        this.liveSparkCacheService = liveSparkCacheService;
        this.notificationService = notificationService;
        this.aiModerationService = aiModerationService;
    }

    @Transactional
    public SparkEventEntity createSpark(CreateSparkCommand command) {
        Instant now = Instant.now();
        if (command.startsAt().isAfter(now.plus(Duration.ofHours(24)))) {
            throw new IllegalArgumentException("Spark start time must be within 24 hours.");
        }
        long activeCreated = sparkEventRepository.countByHostUserIdAndStatusAndStartsAtAfter(
                command.hostUserId(),
                SparkStatus.ACTIVE,
                now
        );
        if (activeCreated >= 5) {
            throw new IllegalStateException("You already have 5 active sparks.");
        }
        var moderation = aiModerationService.moderateSparkContent(command.title(), command.note());
        if (!moderation.allowed()) {
            throw new IllegalArgumentException(moderation.reason());
        }

        SparkEventEntity entity = new SparkEventEntity();
        entity.setHostUserId(command.hostUserId());
        entity.setCategory(command.category());
        entity.setTitle(moderation.safeTitle());
        entity.setNote((moderation.safeNote() == null || moderation.safeNote().isBlank())
                ? null
                : moderation.safeNote());
        entity.setLocationName(command.locationName());
        entity.setLatitude(command.latitude());
        entity.setLongitude(command.longitude());
        entity.setStartsAt(command.startsAt());
        entity.setEndsAt(command.endsAt());
        entity.setMaxSpots(command.maxSpots());
        entity.setStatus(SparkStatus.ACTIVE);

        SparkEventEntity saved = sparkEventRepository.save(entity);
        syncLiveCache(saved);
        return saved;
    }

    @Transactional
    public SparkEventEntity joinSpark(UUID sparkId, String userId) {
        SparkEventEntity spark = activeSpark(sparkId);
        if (spark.getHostUserId().equals(userId)) {
            throw new IllegalStateException("Host cannot join their own spark.");
        }
        SparkParticipantEntity participant = sparkParticipantRepository
                .findBySparkIdAndUserId(sparkId, userId)
                .orElse(null);

        if (participant == null) {
            long joined = sparkParticipantRepository.countBySparkIdAndStatus(sparkId, ParticipantStatus.JOINED);
            if (joined >= spark.getMaxSpots()) {
                throw new IllegalStateException("No spots left.");
            }
            participant = new SparkParticipantEntity();
            participant.setSparkId(sparkId);
            participant.setUserId(userId);
            participant.setStatus(ParticipantStatus.JOINED);
            sparkParticipantRepository.save(participant);
            notificationService.onParticipantJoined(spark, userId);
        } else if (participant.getStatus() == ParticipantStatus.LEFT) {
            long joined = sparkParticipantRepository.countBySparkIdAndStatus(sparkId, ParticipantStatus.JOINED);
            if (joined >= spark.getMaxSpots()) {
                throw new IllegalStateException("No spots left.");
            }
            participant.setStatus(ParticipantStatus.JOINED);
            sparkParticipantRepository.save(participant);
            notificationService.onParticipantJoined(spark, userId);
        }

        long joinedAfter = sparkParticipantRepository.countBySparkIdAndStatus(sparkId, ParticipantStatus.JOINED);
        int spotsLeft = Math.max(spark.getMaxSpots() - (int) joinedAfter, 0);
        notificationService.onFillingFast(spark, spotsLeft);
        syncLiveCache(spark);
        return spark;
    }

    @Transactional
    public SparkEventEntity leaveSpark(UUID sparkId, String userId) {
        SparkEventEntity spark = activeSpark(sparkId);
        SparkParticipantEntity participant = sparkParticipantRepository
                .findBySparkIdAndUserId(sparkId, userId)
                .orElseThrow(() -> new EntityNotFoundException("Participant not found."));
        participant.setStatus(ParticipantStatus.LEFT);
        sparkParticipantRepository.save(participant);
        notificationService.onParticipantLeft(spark, userId);
        syncLiveCache(spark);
        return spark;
    }

    public LiveSparkCacheService.NearbyPage nearby(double lat, double lng, double radiusKm, int page, int size) {
        return liveSparkCacheService.findNearby(lat, lng, radiusKm, page, size);
    }

    public SparkEventEntity getSpark(UUID sparkId) {
        return sparkEventRepository.findById(sparkId)
                .orElseThrow(() -> new EntityNotFoundException("Spark not found."));
    }

    public long joinedCount(UUID sparkId) {
        return sparkParticipantRepository.countBySparkIdAndStatus(sparkId, ParticipantStatus.JOINED);
    }

    public boolean isJoined(UUID sparkId, String userId) {
        return sparkParticipantRepository.findBySparkIdAndUserId(sparkId, userId)
                .map(p -> p.getStatus() == ParticipantStatus.JOINED)
                .orElse(false);
    }

    private SparkEventEntity activeSpark(UUID sparkId) {
        return sparkEventRepository.findByIdAndStatus(sparkId, SparkStatus.ACTIVE)
                .orElseThrow(() -> new EntityNotFoundException("Active spark not found."));
    }

    private void syncLiveCache(SparkEventEntity spark) {
        long joined = sparkParticipantRepository.countBySparkIdAndStatus(spark.getId(), ParticipantStatus.JOINED);
        Duration ttl = Duration.ofSeconds(liveSparkCacheService.defaultTtlSeconds());
        liveSparkCacheService.upsert(
                new LiveSparkCacheService.LiveSpark(
                        spark.getId(),
                        spark.getTitle(),
                        spark.getCategory(),
                        spark.getLocationName(),
                        spark.getLatitude(),
                        spark.getLongitude(),
                        spark.getStartsAt(),
                        spark.getMaxSpots(),
                        (int) joined,
                        spark.getHostUserId()
                ),
                ttl
        );
    }

    public record CreateSparkCommand(
            String hostUserId,
            String category,
            String title,
            String note,
            String locationName,
            double latitude,
            double longitude,
            Instant startsAt,
            Instant endsAt,
            int maxSpots
    ) {
    }
}
