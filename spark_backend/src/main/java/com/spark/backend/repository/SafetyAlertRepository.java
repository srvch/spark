package com.spark.backend.repository;

import com.spark.backend.entity.SafetyAlertEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface SafetyAlertRepository extends JpaRepository<SafetyAlertEntity, UUID> {
}
