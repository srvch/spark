package com.spark.backend.repository;

import com.spark.backend.domain.ParticipantStatus;
import com.spark.backend.entity.SparkParticipantEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SparkParticipantRepository extends JpaRepository<SparkParticipantEntity, Long> {
    Optional<SparkParticipantEntity> findBySparkIdAndUserId(UUID sparkId, String userId);

    long countBySparkIdAndStatus(UUID sparkId, ParticipantStatus status);

    List<SparkParticipantEntity> findBySparkIdAndStatus(UUID sparkId, ParticipantStatus status);

    @Transactional
    @Modifying
    @Query("delete from SparkParticipantEntity p where p.userId = :userId")
    void deleteByUserId(@Param("userId") String userId);

    @Transactional
    @Modifying
    @Query("delete from SparkParticipantEntity p where p.sparkId = :sparkId")
    void deleteBySparkId(@Param("sparkId") UUID sparkId);
}
