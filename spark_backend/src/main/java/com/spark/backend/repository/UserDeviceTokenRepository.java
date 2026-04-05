package com.spark.backend.repository;

import com.spark.backend.entity.UserDeviceTokenEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

public interface UserDeviceTokenRepository extends JpaRepository<UserDeviceTokenEntity, String> {
    List<UserDeviceTokenEntity> findByUserIdAndActiveTrue(String userId);

    List<UserDeviceTokenEntity> findByUserIdInAndActiveTrue(List<String> userIds);

    @Transactional
    @Modifying
    @Query("delete from UserDeviceTokenEntity t where t.userId = :userId")
    void deleteByUserId(@Param("userId") String userId);
}
