package com.spark.backend.entity;

import com.spark.backend.domain.ParticipantStatus;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "spark_participants",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_spark_participants_spark_user", columnNames = {"spark_id", "user_id"})
        }
)
public class SparkParticipantEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "spark_id", nullable = false)
    private UUID sparkId;

    @Column(name = "user_id", nullable = false, length = 128)
    private String userId;

    @Column(name = "joined_at", nullable = false)
    private Instant joinedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private ParticipantStatus status = ParticipantStatus.JOINED;

    @PrePersist
    void onCreate() {
        joinedAt = Instant.now();
    }

    public Long getId() {
        return id;
    }

    public UUID getSparkId() {
        return sparkId;
    }

    public void setSparkId(UUID sparkId) {
        this.sparkId = sparkId;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public Instant getJoinedAt() {
        return joinedAt;
    }

    public ParticipantStatus getStatus() {
        return status;
    }

    public void setStatus(ParticipantStatus status) {
        this.status = status;
    }
}
