package com.spark.backend.entity;

import com.spark.backend.domain.GroupInviteStatus;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "spark_group_invites",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_group_invites_group_user",
                        columnNames = {"group_id", "invitee_user_id"}
                )
        }
)
public class SparkGroupInviteEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Column(name = "inviter_user_id", nullable = false, length = 128)
    private String inviterUserId;

    @Column(name = "invitee_user_id", nullable = false, length = 128)
    private String inviteeUserId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private GroupInviteStatus status = GroupInviteStatus.PENDING;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "acted_at")
    private Instant actedAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public UUID getGroupId() {
        return groupId;
    }

    public void setGroupId(UUID groupId) {
        this.groupId = groupId;
    }

    public String getInviterUserId() {
        return inviterUserId;
    }

    public void setInviterUserId(String inviterUserId) {
        this.inviterUserId = inviterUserId;
    }

    public String getInviteeUserId() {
        return inviteeUserId;
    }

    public void setInviteeUserId(String inviteeUserId) {
        this.inviteeUserId = inviteeUserId;
    }

    public GroupInviteStatus getStatus() {
        return status;
    }

    public void setStatus(GroupInviteStatus status) {
        this.status = status;
    }

    public Instant getCreatedAt() {
        return createdAt;
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

