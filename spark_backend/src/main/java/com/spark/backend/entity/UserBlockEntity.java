package com.spark.backend.entity;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "user_blocks",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_user_blocks_blocker_blocked",
                        columnNames = {"blocker_user_id", "blocked_user_id"}
                )
        }
)
public class UserBlockEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "blocker_user_id", nullable = false, length = 128)
    private String blockerUserId;

    @Column(name = "blocked_user_id", nullable = false, length = 128)
    private String blockedUserId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
    }

    public UUID getId() { return id; }

    public String getBlockerUserId() { return blockerUserId; }
    public void setBlockerUserId(String blockerUserId) { this.blockerUserId = blockerUserId; }

    public String getBlockedUserId() { return blockedUserId; }
    public void setBlockedUserId(String blockedUserId) { this.blockedUserId = blockedUserId; }

    public Instant getCreatedAt() { return createdAt; }
}
