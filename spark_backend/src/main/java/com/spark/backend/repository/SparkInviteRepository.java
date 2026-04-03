package com.spark.backend.repository;

import com.spark.backend.entity.SparkInviteEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SparkInviteRepository extends JpaRepository<SparkInviteEntity, UUID> {
    Optional<SparkInviteEntity> findBySparkIdAndToUserId(UUID sparkId, String toUserId);
    Optional<SparkInviteEntity> findByIdAndSparkIdAndToUserId(UUID id, UUID sparkId, String toUserId);
    Optional<SparkInviteEntity> findByIdAndSparkId(UUID id, UUID sparkId);

    List<SparkInviteEntity> findBySparkId(UUID sparkId);

    Page<SparkInviteEntity> findByToUserIdOrderByInvitedAtDesc(String toUserId, Pageable pageable);
    Page<SparkInviteEntity> findByToUserIdInOrderByInvitedAtDesc(List<String> toUserIds, Pageable pageable);
}
