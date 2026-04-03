package com.spark.backend.repository;

import com.spark.backend.entity.SparkGroupMemberEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SparkGroupMemberRepository extends JpaRepository<SparkGroupMemberEntity, UUID> {
    Optional<SparkGroupMemberEntity> findByGroupIdAndUserId(UUID groupId, String userId);

    List<SparkGroupMemberEntity> findByGroupIdOrderByCreatedAtAsc(UUID groupId);

    List<SparkGroupMemberEntity> findByUserIdOrderByCreatedAtDesc(String userId);

    long countByGroupId(UUID groupId);
}

