package com.spark.backend.repository;

import com.spark.backend.domain.NotificationType;
import com.spark.backend.entity.UserNotificationEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

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

    @Transactional
    @Modifying
    @Query("delete from UserNotificationEntity n where n.recipientUserId = :userId")
    void deleteByRecipientUserId(@Param("userId") String userId);
}
