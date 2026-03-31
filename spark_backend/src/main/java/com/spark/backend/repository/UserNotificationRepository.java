package com.spark.backend.repository;

import com.spark.backend.domain.NotificationType;
import com.spark.backend.entity.UserNotificationEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserNotificationRepository extends JpaRepository<UserNotificationEntity, UUID> {
    List<UserNotificationEntity> findTop50ByRecipientUserIdOrderByCreatedAtDesc(String recipientUserId);

    List<UserNotificationEntity> findTop50ByRecipientUserIdAndReadAtIsNullOrderByCreatedAtDesc(String recipientUserId);

    Optional<UserNotificationEntity> findByDedupeKey(String dedupeKey);

    Optional<UserNotificationEntity> findTopByRecipientUserIdAndSparkIdAndTypeAndReadAtIsNullAndCreatedAtAfterOrderByCreatedAtDesc(
            String recipientUserId,
            UUID sparkId,
            NotificationType type,
            Instant createdAfter
    );
}
