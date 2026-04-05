package com.spark.backend.repository;

import com.spark.backend.entity.SparkGroupMemberEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SparkGroupMemberRepository extends JpaRepository<SparkGroupMemberEntity, UUID> {
    Optional<SparkGroupMemberEntity> findByGroupIdAndUserId(UUID groupId, String userId);

    List<SparkGroupMemberEntity> findByGroupIdOrderByCreatedAtAsc(UUID groupId);

    List<SparkGroupMemberEntity> findByUserIdOrderByCreatedAtDesc(String userId);

    long countByGroupId(UUID groupId);

    @Transactional
    @Modifying
    @Query("delete from SparkGroupMemberEntity m where m.userId = :userId")
    void deleteByUserId(@Param("userId") String userId);

    @Transactional
    @Modifying
    @Query("delete from SparkGroupMemberEntity m where m.groupId = :groupId")
    void deleteByGroupId(@Param("groupId") UUID groupId);
}

