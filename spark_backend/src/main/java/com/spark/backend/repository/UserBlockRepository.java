package com.spark.backend.repository;

import com.spark.backend.entity.UserBlockEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

public interface UserBlockRepository extends JpaRepository<UserBlockEntity, UUID> {
    Optional<UserBlockEntity> findByBlockerUserIdAndBlockedUserId(String blockerUserId, String blockedUserId);
    boolean existsByBlockerUserIdAndBlockedUserId(String blockerUserId, String blockedUserId);

    @Transactional
    @Modifying
    @Query("delete from UserBlockEntity b where b.blockerUserId = :userId or b.blockedUserId = :userId")
    void deleteByUser(@Param("userId") String userId);
}
