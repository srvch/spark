package com.spark.backend.service;

import com.spark.backend.domain.ParticipantStatus;
import com.spark.backend.domain.SparkInviteStatus;
import com.spark.backend.domain.SparkStatus;
import com.spark.backend.domain.SparkVisibility;
import com.spark.backend.entity.AppUserEntity;
import com.spark.backend.entity.SparkEventEntity;
import com.spark.backend.entity.SparkInviteEntity;
import com.spark.backend.entity.SparkParticipantEntity;
import com.spark.backend.repository.AppUserRepository;
import com.spark.backend.repository.SparkEventRepository;
import com.spark.backend.repository.SparkInviteRepository;
import com.spark.backend.repository.SparkParticipantRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.transaction.Transactional;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

@Service
public class SparkService {
    private final SparkEventRepository sparkEventRepository;
    private final SparkParticipantRepository sparkParticipantRepository;
    private final SparkInviteRepository sparkInviteRepository;
    private final AppUserRepository appUserRepository;
    private final LiveSparkCacheService liveSparkCacheService;
    private final NotificationService notificationService;
    private final AiModerationService aiModerationService;

    public SparkService(
            SparkEventRepository sparkEventRepository,
            SparkParticipantRepository sparkParticipantRepository,
            SparkInviteRepository sparkInviteRepository,
            AppUserRepository appUserRepository,
            LiveSparkCacheService liveSparkCacheService,
            NotificationService notificationService,
            AiModerationService aiModerationService
    ) {
        this.sparkEventRepository = sparkEventRepository;
        this.sparkParticipantRepository = sparkParticipantRepository;
        this.sparkInviteRepository = sparkInviteRepository;
        this.appUserRepository = appUserRepository;
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
        entity.setVisibility(command.visibility());
        entity.setStatus(SparkStatus.ACTIVE);

        SparkEventEntity saved = sparkEventRepository.save(entity);
        if (command.visibility() == SparkVisibility.INVITE) {
            createPendingInvites(saved.getId(), command.hostUserId(), command.inviteUserIds());
        }
        syncLiveCache(saved);
        return saved;
    }

    @Transactional
    public SparkInviteEntity respondToInvite(
            UUID sparkId,
            UUID inviteId,
            String userId,
            String userPhoneNumber,
            SparkInviteStatus nextStatus
    ) {
        SparkEventEntity spark = activeSpark(sparkId);
        SparkInviteEntity invite = sparkInviteRepository.findByIdAndSparkId(inviteId, sparkId)
                .orElseThrow(() -> new EntityNotFoundException("Invite not found."));
        ensureInviteBelongsToCurrentUser(invite, userId, userPhoneNumber);

        SparkInviteStatus current = invite.getStatus();
        if (current == nextStatus) {
            return invite;
        }
        if (!isAllowedTransition(current, nextStatus)) {
            throw new IllegalStateException("Invalid invite status transition: " + current + " -> " + nextStatus);
        }
        if (nextStatus == SparkInviteStatus.IN) {
            ensureJoinedViaInvite(spark, userId);
            notificationService.onParticipantJoined(spark, userId);
            long joinedAfter = sparkParticipantRepository.countBySparkIdAndStatus(sparkId, ParticipantStatus.JOINED);
            int spotsLeft = Math.max(spark.getMaxSpots() - (int) joinedAfter, 0);
            notificationService.onFillingFast(spark, spotsLeft);
            syncLiveCache(spark);
        }
        if (!userId.equals(invite.getToUserId())) {
            SparkInviteEntity canonicalInvite = sparkInviteRepository.findBySparkIdAndToUserId(sparkId, userId)
                    .orElse(null);
            if (canonicalInvite != null && !canonicalInvite.getId().equals(invite.getId())) {
                invite = canonicalInvite;
            } else {
                invite.setToUserId(userId);
            }
        }
        invite.setStatus(nextStatus);
        invite.setActedAt(Instant.now());
        return sparkInviteRepository.save(invite);
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

    public InviteInboxPage listInvitesForUser(String userId, String userPhoneNumber, int page, int size) {
        String normalizedPhone = normalizePhone(userPhoneNumber);
        List<String> inboxKeys = normalizedPhone == null ? List.of(userId) : List.of(userId, normalizedPhone);
        var invitePage = sparkInviteRepository.findByToUserIdInOrderByInvitedAtDesc(
                inboxKeys,
                PageRequest.of(page, size)
        );
        List<SparkInviteEntity> invites = dedupeInvitePage(invitePage.getContent(), userId);
        Set<UUID> sparkIds = invites.stream().map(SparkInviteEntity::getSparkId).collect(LinkedHashSet::new, Set::add, Set::addAll);
        Map<UUID, SparkEventEntity> sparksById = new HashMap<>();
        if (!sparkIds.isEmpty()) {
            sparkEventRepository.findAllById(sparkIds).forEach(spark -> sparksById.put(spark.getId(), spark));
        }
        List<InviteInboxItem> items = invites.stream().map(invite -> {
            SparkEventEntity spark = sparksById.get(invite.getSparkId());
            String title = spark != null ? spark.getTitle() : "Spark unavailable";
            String category = spark != null ? spark.getCategory() : "unknown";
            String locationName = spark != null ? spark.getLocationName() : "";
            Instant startsAt = spark != null ? spark.getStartsAt() : null;
            String sparkStatus = spark != null ? spark.getStatus().name() : "UNKNOWN";
            return new InviteInboxItem(
                    invite.getId(),
                    invite.getSparkId(),
                    invite.getFromUserId(),
                    recipientType(invite.getToUserId()),
                    invite.getToUserId(),
                    invite.getStatus().name(),
                    invite.getInvitedAt(),
                    invite.getActedAt(),
                    title,
                    category,
                    locationName,
                    startsAt,
                    sparkStatus
            );
        }).toList();
        return new InviteInboxPage(items, page, size, invitePage.hasNext());
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

    private void createPendingInvites(UUID sparkId, String hostUserId, List<String> inviteUserIds) {
        Set<String> uniqueRecipients = new LinkedHashSet<>();
        String hostPhone = appUserRepository.findById(UUID.fromString(hostUserId))
                .map(AppUserEntity::getPhoneNumber)
                .orElse(null);
        for (String rawRecipient : inviteUserIds) {
            String recipientId = canonicalRecipientId(rawRecipient);
            if (recipientId == null || recipientId.equals(hostUserId)) continue;
            if (hostPhone != null && hostPhone.equals(recipientId)) continue;
            uniqueRecipients.add(recipientId);
        }
        for (String recipientId : uniqueRecipients) {
            SparkInviteEntity invite = sparkInviteRepository
                    .findBySparkIdAndToUserId(sparkId, recipientId)
                    .orElse(null);
            if (invite == null) {
                invite = new SparkInviteEntity();
                invite.setSparkId(sparkId);
                invite.setFromUserId(hostUserId);
                invite.setToUserId(recipientId);
            }
            invite.setStatus(SparkInviteStatus.PENDING);
            invite.setActedAt(null);
            sparkInviteRepository.save(invite);
        }
    }

    private List<SparkInviteEntity> dedupeInvitePage(List<SparkInviteEntity> invites, String userId) {
        Map<String, SparkInviteEntity> byRecipientAndSpark = new HashMap<>();
        for (SparkInviteEntity invite : invites) {
            String key = invite.getSparkId() + "|" + invite.getFromUserId();
            SparkInviteEntity existing = byRecipientAndSpark.get(key);
            if (existing == null) {
                byRecipientAndSpark.put(key, invite);
                continue;
            }
            boolean inviteIsUser = userId.equals(invite.getToUserId());
            boolean existingIsUser = userId.equals(existing.getToUserId());
            if (inviteIsUser && !existingIsUser) {
                byRecipientAndSpark.put(key, invite);
                continue;
            }
            if (invite.getInvitedAt().isAfter(existing.getInvitedAt())) {
                byRecipientAndSpark.put(key, invite);
            }
        }
        List<SparkInviteEntity> deduped = new ArrayList<>(byRecipientAndSpark.values());
        deduped.sort(Comparator.comparing(SparkInviteEntity::getInvitedAt).reversed());
        return deduped;
    }

    private void ensureInviteBelongsToCurrentUser(SparkInviteEntity invite, String userId, String userPhoneNumber) {
        String toUserId = invite.getToUserId();
        if (userId.equals(toUserId)) {
            return;
        }
        String normalizedPhone = normalizePhone(userPhoneNumber);
        if (normalizedPhone != null && normalizedPhone.equals(toUserId)) {
            return;
        }
        throw new EntityNotFoundException("Invite not found.");
    }

    private String canonicalRecipientId(String rawRecipient) {
        if (rawRecipient == null) {
            return null;
        }
        String trimmed = rawRecipient.trim();
        if (trimmed.isEmpty()) {
            return null;
        }
        try {
            UUID id = UUID.fromString(trimmed);
            return id.toString();
        } catch (IllegalArgumentException ignored) {
            String normalizedPhone = normalizePhone(trimmed);
            if (normalizedPhone == null) {
                return null;
            }
            return appUserRepository.findByPhoneNumber(normalizedPhone)
                    .map(user -> user.getId().toString())
                    .orElse(normalizedPhone);
        }
    }

    private String normalizePhone(String raw) {
        if (raw == null) {
            return null;
        }
        String clean = raw.replaceAll("[^0-9+]", "");
        if (clean.isBlank()) {
            return null;
        }
        if (clean.startsWith("+")) {
            return clean;
        }
        String digits = clean.replaceAll("[^0-9]", "");
        if (digits.length() == 10) {
            return "+91" + digits;
        }
        return "+" + digits;
    }

    private String recipientType(String recipientId) {
        try {
            UUID.fromString(recipientId);
            return "USER_ID";
        } catch (IllegalArgumentException ignored) {
            return "PHONE";
        }
    }

    private boolean isAllowedTransition(SparkInviteStatus current, SparkInviteStatus next) {
        return switch (current) {
            case PENDING -> next == SparkInviteStatus.IN
                    || next == SparkInviteStatus.MAYBE
                    || next == SparkInviteStatus.DECLINED;
            case MAYBE -> next == SparkInviteStatus.IN
                    || next == SparkInviteStatus.DECLINED;
            case DECLINED -> next == SparkInviteStatus.IN
                    || next == SparkInviteStatus.MAYBE;
            case IN -> false;
        };
    }

    private void ensureJoinedViaInvite(SparkEventEntity spark, String userId) {
        if (spark.getHostUserId().equals(userId)) {
            throw new IllegalStateException("Host cannot join their own spark.");
        }
        SparkParticipantEntity participant = sparkParticipantRepository
                .findBySparkIdAndUserId(spark.getId(), userId)
                .orElse(null);

        if (participant == null) {
            long joined = sparkParticipantRepository.countBySparkIdAndStatus(spark.getId(), ParticipantStatus.JOINED);
            if (joined >= spark.getMaxSpots()) {
                throw new IllegalStateException("No spots left.");
            }
            participant = new SparkParticipantEntity();
            participant.setSparkId(spark.getId());
            participant.setUserId(userId);
            participant.setStatus(ParticipantStatus.JOINED);
            sparkParticipantRepository.save(participant);
            return;
        }
        if (participant.getStatus() == ParticipantStatus.LEFT) {
            long joined = sparkParticipantRepository.countBySparkIdAndStatus(spark.getId(), ParticipantStatus.JOINED);
            if (joined >= spark.getMaxSpots()) {
                throw new IllegalStateException("No spots left.");
            }
            participant.setStatus(ParticipantStatus.JOINED);
            sparkParticipantRepository.save(participant);
        }
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
            int maxSpots,
            SparkVisibility visibility,
            List<UUID> circleIds,
            List<String> inviteUserIds
    ) {
    }

    public record InviteInboxItem(
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

    public record InviteInboxPage(
            List<InviteInboxItem> items,
            int page,
            int size,
            boolean hasMore
    ) {
    }
}
