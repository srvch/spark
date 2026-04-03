package com.spark.backend.repository;

import com.spark.backend.entity.UserBlockEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface UserBlockRepository extends JpaRepository<UserBlockEntity, UUID> {
    Optional<UserBlockEntity> findByBlockerUserIdAndBlockedUserId(String blockerUserId, String blockedUserId);
    boolean existsByBlockerUserIdAndBlockedUserId(String blockerUserId, String blockedUserId);
}
