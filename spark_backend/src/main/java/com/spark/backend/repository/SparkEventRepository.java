package com.spark.backend.repository;

import com.spark.backend.domain.SparkStatus;
import com.spark.backend.entity.SparkEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SparkEventRepository extends JpaRepository<SparkEventEntity, UUID> {
    Optional<SparkEventEntity> findByIdAndStatus(UUID id, SparkStatus status);

    long countByHostUserIdAndStatusAndStartsAtAfter(String hostUserId, SparkStatus status, Instant startsAt);

    List<SparkEventEntity> findByStatusAndStartsAtBetween(SparkStatus status, Instant from, Instant to);

    List<SparkEventEntity> findByHostUserIdInOrderByStartsAtDesc(java.util.Collection<String> hostUserIds);

    List<SparkEventEntity> findByHostUserId(String hostUserId);
}
