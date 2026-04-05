package com.spark.backend.repository;

import com.spark.backend.domain.SparkStatus;
import com.spark.backend.entity.SparkEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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

    /** Find active recurring templates whose next spawn time is due */
    @Query("""
            select s from SparkEventEntity s
            where s.recurrenceType is not null
              and s.status = 'ACTIVE'
              and s.templateId is null
              and (s.recurrenceEndDate is null or s.recurrenceEndDate >= cast(:today as java.time.LocalDate))
              and (s.nextOccursAt is null or s.nextOccursAt <= :horizon)
            """)
    List<SparkEventEntity> findDueRecurringTemplates(
            @Param("horizon") Instant horizon,
            @Param("today") Instant today
    );

    /** Find sparks created after a given time for proactive alerts */
    List<SparkEventEntity> findByCreatedAtAfterAndStatus(Instant since, SparkStatus status);
}
