package com.spark.backend.repository;

import com.spark.backend.domain.GroupInviteStatus;
import com.spark.backend.entity.SparkGroupInviteEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SparkGroupInviteRepository extends JpaRepository<SparkGroupInviteEntity, UUID> {
    Optional<SparkGroupInviteEntity> findByGroupIdAndInviteeUserId(UUID groupId, String inviteeUserId);

    Optional<SparkGroupInviteEntity> findByIdAndGroupIdAndInviteeUserId(UUID id, UUID groupId, String inviteeUserId);

    List<SparkGroupInviteEntity> findByInviteeUserIdAndStatusOrderByCreatedAtDesc(String inviteeUserId, GroupInviteStatus status);

    List<SparkGroupInviteEntity> findByGroupIdAndStatusOrderByCreatedAtDesc(UUID groupId, GroupInviteStatus status);
}

