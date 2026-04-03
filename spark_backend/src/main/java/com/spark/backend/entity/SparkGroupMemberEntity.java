package com.spark.backend.entity;

import com.spark.backend.domain.GroupMemberRole;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
        name = "spark_group_members",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_group_members_group_user",
                        columnNames = {"group_id", "user_id"}
                )
        }
)
public class SparkGroupMemberEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "group_id", nullable = false)
    private UUID groupId;

    @Column(name = "user_id", nullable = false, length = 128)
    private String userId;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 16)
    private GroupMemberRole role = GroupMemberRole.MEMBER;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

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

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public GroupMemberRole getRole() {
        return role;
    }

    public void setRole(GroupMemberRole role) {
        this.role = role;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}

