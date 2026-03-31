package com.spark.backend.service;

import com.spark.backend.domain.NotificationType;
import com.spark.backend.domain.ParticipantStatus;
import com.spark.backend.entity.AppUserEntity;
import com.spark.backend.entity.NotificationPreferenceEntity;
import com.spark.backend.entity.SparkEventEntity;
import com.spark.backend.entity.SparkParticipantEntity;
import com.spark.backend.entity.UserNotificationEntity;
import com.spark.backend.repository.AppUserRepository;
import com.spark.backend.repository.NotificationPreferenceRepository;
import com.spark.backend.repository.SparkParticipantRepository;
import com.spark.backend.repository.UserNotificationRepository;
import jakarta.transaction.Transactional;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

@Service
public class NotificationService {
    private final UserNotificationRepository userNotificationRepository;
    private final NotificationPreferenceRepository notificationPreferenceRepository;
    private final SparkParticipantRepository sparkParticipantRepository;
    private final AppUserRepository appUserRepository;
    private final PushProvider pushProvider;

    public NotificationService(
            UserNotificationRepository userNotificationRepository,
            NotificationPreferenceRepository notificationPreferenceRepository,
            SparkParticipantRepository sparkParticipantRepository,
            AppUserRepository appUserRepository,
            PushProvider pushProvider
    ) {
        this.userNotificationRepository = userNotificationRepository;
        this.notificationPreferenceRepository = notificationPreferenceRepository;
        this.sparkParticipantRepository = sparkParticipantRepository;
        this.appUserRepository = appUserRepository;
        this.pushProvider = pushProvider;
    }

    @Transactional
    public void onParticipantJoined(SparkEventEntity spark, String joinedUserId) {
        String joinedName = displayNameOf(joinedUserId).orElse("Someone");
        Set<String> recipientIds = new HashSet<>();
        recipientIds.add(spark.getHostUserId());
        recipientIds.addAll(joinedParticipants(spark.getId()));
        recipientIds.remove(joinedUserId);

        for (String recipientId : recipientIds) {
            if (!prefs(recipientId).isNotifyJoin()) {
                continue;
            }
            upsertJoinBatchNotification(recipientId, spark, joinedUserId, joinedName);
        }
    }

    @Transactional
    public void onParticipantLeft(SparkEventEntity spark, String leftUserId) {
        String hostId = spark.getHostUserId();
        if (hostId.equals(leftUserId)) {
            return;
        }
        if (!prefs(hostId).isNotifyLeaveHost()) {
            return;
        }
        String leftName = displayNameOf(leftUserId).orElse("Someone");
        createNotification(
                hostId,
                spark.getId(),
                leftUserId,
                NotificationType.PARTICIPANT_LEFT,
                leftName + " left \"" + spark.getTitle() + "\"",
                "A participant left your spark.",
                null
        );
    }

    @Transactional
    public void onFillingFast(SparkEventEntity spark, int spotsLeft) {
        if (spotsLeft != 1) {
            return;
        }
        Set<String> recipientIds = new HashSet<>();
        recipientIds.add(spark.getHostUserId());
        recipientIds.addAll(joinedParticipants(spark.getId()));

        for (String recipientId : recipientIds) {
            if (!prefs(recipientId).isNotifyFillingFast()) {
                continue;
            }
            String dedupe = "filling_fast:" + spark.getId() + ":" + recipientId;
            createNotificationIfMissing(
                    recipientId,
                    spark.getId(),
                    spark.getHostUserId(),
                    NotificationType.SPARK_FILLING_FAST,
                    "Only 1 spot left in \"" + spark.getTitle() + "\"",
                    "This spark is filling fast.",
                    dedupe
            );
        }
    }

    @Transactional
    public void sendStartsSoonReminder(SparkEventEntity spark, int minutesBeforeStart) {
        NotificationType type = minutesBeforeStart == 60
                ? NotificationType.SPARK_STARTS_60
                : NotificationType.SPARK_STARTS_15;
        Set<String> recipientIds = new HashSet<>();
        recipientIds.add(spark.getHostUserId());
        recipientIds.addAll(joinedParticipants(spark.getId()));

        for (String recipientId : recipientIds) {
            NotificationPreferenceEntity pref = prefs(recipientId);
            if (minutesBeforeStart == 60 && !pref.isNotifyStarts60()) {
                continue;
            }
            if (minutesBeforeStart == 15 && !pref.isNotifyStarts15()) {
                continue;
            }
            String dedupe = "starts_" + minutesBeforeStart + ":" + spark.getId() + ":" + recipientId;
            createNotificationIfMissing(
                    recipientId,
                    spark.getId(),
                    spark.getHostUserId(),
                    type,
                    "\"" + spark.getTitle() + "\" starts in " + minutesBeforeStart + " min",
                    "Be ready. It starts soon.",
                    dedupe
            );
        }
    }

    @Transactional
    public void notifyHostModerationAction(
            SparkEventEntity spark,
            String affectedUserId,
            boolean blocked
    ) {
        createNotification(
                affectedUserId,
                spark.getId(),
                spark.getHostUserId(),
                blocked ? NotificationType.HOST_BLOCKED_YOU : NotificationType.HOST_REMOVED_YOU,
                blocked
                        ? "You were blocked from \"" + spark.getTitle() + "\""
                        : "You were removed from \"" + spark.getTitle() + "\"",
                blocked
                        ? "Host blocked you from this spark."
                        : "Host removed you from this spark.",
                null
        );
    }

    public List<UserNotificationEntity> listForUser(String userId, boolean unreadOnly) {
        if (unreadOnly) {
            return userNotificationRepository.findTop50ByRecipientUserIdAndReadAtIsNullOrderByCreatedAtDesc(userId);
        }
        return userNotificationRepository.findTop50ByRecipientUserIdOrderByCreatedAtDesc(userId);
    }

    @Transactional
    public void markRead(String userId, UUID notificationId) {
        UserNotificationEntity entity = userNotificationRepository.findById(notificationId)
                .orElseThrow(() -> new IllegalArgumentException("Notification not found"));
        if (!entity.getRecipientUserId().equals(userId)) {
            throw new IllegalArgumentException("Cannot mark another user's notification.");
        }
        if (entity.getReadAt() == null) {
            entity.setReadAt(Instant.now());
            userNotificationRepository.save(entity);
        }
    }

    public NotificationPreferenceEntity getPreferences(String userId) {
        return prefs(userId);
    }

    @Transactional
    public NotificationPreferenceEntity upsertPreferences(String userId, PreferencesUpdate update) {
        NotificationPreferenceEntity entity = prefs(userId);
        entity.setNotifyJoin(update.notifyJoin());
        entity.setNotifyLeaveHost(update.notifyLeaveHost());
        entity.setNotifyFillingFast(update.notifyFillingFast());
        entity.setNotifyStarts15(update.notifyStarts15());
        entity.setNotifyStarts60(update.notifyStarts60());
        entity.setNotifyNewNearby(update.notifyNewNearby());
        entity.setInterestCategories(update.interestCategories());
        entity.setRadiusKm(update.radiusKm());
        return notificationPreferenceRepository.save(entity);
    }

    private void upsertJoinBatchNotification(
            String recipientId,
            SparkEventEntity spark,
            String actorUserId,
            String actorName
    ) {
        Instant cutoff = Instant.now().minusSeconds(60);
        Optional<UserNotificationEntity> existingOpt =
                userNotificationRepository
                        .findTopByRecipientUserIdAndSparkIdAndTypeAndReadAtIsNullAndCreatedAtAfterOrderByCreatedAtDesc(
                                recipientId,
                                spark.getId(),
                                NotificationType.PARTICIPANT_JOINED,
                                cutoff
                        );
        if (existingOpt.isPresent()) {
            UserNotificationEntity existing = existingOpt.get();
            int nextCount = Math.max(existing.getBatchCount(), 1) + 1;
            existing.setBatchCount(nextCount);
            existing.setActorUserId(actorUserId);
            existing.setTitle(nextCount + " people joined \"" + spark.getTitle() + "\"");
            existing.setBody("Recent activity in your spark.");
            UserNotificationEntity updated = userNotificationRepository.save(existing);
            pushProvider.sendToUsers(
                    List.of(recipientId),
                    NotificationType.PARTICIPANT_JOINED,
                    spark.getId(),
                    updated
            );
            return;
        }

            UserNotificationEntity created = createNotification(
                    recipientId,
                    spark.getId(),
                    actorUserId,
                NotificationType.PARTICIPANT_JOINED,
                actorName + " joined \"" + spark.getTitle() + "\"",
                    "New participant joined your spark.",
                    null
            );
            pushProvider.sendToUsers(List.of(recipientId), NotificationType.PARTICIPANT_JOINED, spark.getId(), created);
            return;
        }

    private List<String> joinedParticipants(UUID sparkId) {
        return sparkParticipantRepository.findBySparkIdAndStatus(sparkId, ParticipantStatus.JOINED)
                .stream()
                .map(SparkParticipantEntity::getUserId)
                .toList();
    }

    private Optional<String> displayNameOf(String userId) {
        try {
            UUID uuid = UUID.fromString(userId);
            return appUserRepository.findById(uuid).map(AppUserEntity::getDisplayName);
        } catch (Exception ignored) {
            return Optional.empty();
        }
    }

    private NotificationPreferenceEntity prefs(String userId) {
        return notificationPreferenceRepository.findById(userId).orElseGet(() -> {
            NotificationPreferenceEntity entity = new NotificationPreferenceEntity();
            entity.setUserId(userId);
            return notificationPreferenceRepository.save(entity);
        });
    }

    private UserNotificationEntity createNotification(
            String recipientUserId,
            UUID sparkId,
            String actorUserId,
            NotificationType type,
            String title,
            String body,
            String dedupeKey
    ) {
        UserNotificationEntity entity = new UserNotificationEntity();
        entity.setRecipientUserId(recipientUserId);
        entity.setSparkId(sparkId);
        entity.setActorUserId(actorUserId);
        entity.setType(type);
        entity.setTitle(title);
        entity.setBody(body);
        entity.setBatchCount(1);
        entity.setDedupeKey(dedupeKey);
        UserNotificationEntity saved = userNotificationRepository.save(entity);
        pushProvider.sendToUsers(
                List.of(recipientUserId),
                type,
                sparkId,
                saved
        );
        return saved;
    }

    private void createNotificationIfMissing(
            String recipientUserId,
            UUID sparkId,
            String actorUserId,
            NotificationType type,
            String title,
            String body,
            String dedupeKey
    ) {
        if (dedupeKey == null) {
            createNotification(recipientUserId, sparkId, actorUserId, type, title, body, null);
            return;
        }
        if (userNotificationRepository.findByDedupeKey(dedupeKey).isPresent()) {
            return;
        }
        try {
            createNotification(recipientUserId, sparkId, actorUserId, type, title, body, dedupeKey);
        } catch (DataIntegrityViolationException ignored) {
            // Deduplication guard in concurrent updates.
        }
    }

    public record PreferencesUpdate(
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
