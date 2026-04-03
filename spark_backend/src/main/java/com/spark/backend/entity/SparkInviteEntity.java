package com.spark.backend.entity;

import com.spark.backend.domain.SparkInviteStatus;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "spark_invites",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_spark_invites_spark_to_user",
                        columnNames = {"spark_id", "to_user_id"}
                )
        }
)
public class SparkInviteEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "spark_id", nullable = false)
    private UUID sparkId;

    @Column(name = "from_user_id", nullable = false, length = 128)
    private String fromUserId;

    @Column(name = "to_user_id", nullable = false, length = 128)
    private String toUserId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private SparkInviteStatus status = SparkInviteStatus.PENDING;

    @Column(name = "invited_at", nullable = false)
    private Instant invitedAt;

    @Column(name = "acted_at")
    private Instant actedAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        invitedAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public UUID getSparkId() {
        return sparkId;
    }

    public void setSparkId(UUID sparkId) {
        this.sparkId = sparkId;
    }

    public String getFromUserId() {
        return fromUserId;
    }

    public void setFromUserId(String fromUserId) {
        this.fromUserId = fromUserId;
    }

    public String getToUserId() {
        return toUserId;
    }

    public void setToUserId(String toUserId) {
        this.toUserId = toUserId;
    }

    public SparkInviteStatus getStatus() {
        return status;
    }

    public void setStatus(SparkInviteStatus status) {
        this.status = status;
    }

    public Instant getInvitedAt() {
        return invitedAt;
    }

    public Instant getActedAt() {
        return actedAt;
    }

    public void setActedAt(Instant actedAt) {
        this.actedAt = actedAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}

