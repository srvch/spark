package com.spark.backend.repository;

import com.spark.backend.entity.AppUserEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface AppUserRepository extends JpaRepository<AppUserEntity, UUID> {
    Optional<AppUserEntity> findByPhoneNumber(String phoneNumber);
    boolean existsByHandleIgnoreCase(String handle);
}
