package com.spark.backend.repository;

import com.spark.backend.entity.UserDeviceTokenEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface UserDeviceTokenRepository extends JpaRepository<UserDeviceTokenEntity, String> {
    List<UserDeviceTokenEntity> findByUserIdAndActiveTrue(String userId);

    List<UserDeviceTokenEntity> findByUserIdInAndActiveTrue(List<String> userIds);
}
