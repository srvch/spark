package com.spark.backend.repository;

import com.spark.backend.entity.SparkGroupEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface SparkGroupRepository extends JpaRepository<SparkGroupEntity, UUID> {
    List<SparkGroupEntity> findByOwnerUserId(String ownerUserId);
}
