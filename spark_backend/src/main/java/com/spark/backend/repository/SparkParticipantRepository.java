package com.spark.backend.repository;

import com.spark.backend.domain.ParticipantStatus;
import com.spark.backend.entity.SparkParticipantEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SparkParticipantRepository extends JpaRepository<SparkParticipantEntity, Long> {
    Optional<SparkParticipantEntity> findBySparkIdAndUserId(UUID sparkId, String userId);

    long countBySparkIdAndStatus(UUID sparkId, ParticipantStatus status);

    List<SparkParticipantEntity> findBySparkIdAndStatus(UUID sparkId, ParticipantStatus status);
}
