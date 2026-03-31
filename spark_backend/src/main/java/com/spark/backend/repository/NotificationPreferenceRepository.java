package com.spark.backend.repository;

import com.spark.backend.entity.NotificationPreferenceEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface NotificationPreferenceRepository extends JpaRepository<NotificationPreferenceEntity, String> {
}
