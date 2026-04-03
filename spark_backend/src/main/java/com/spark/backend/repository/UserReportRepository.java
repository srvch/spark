package com.spark.backend.repository;

import com.spark.backend.entity.UserReportEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface UserReportRepository extends JpaRepository<UserReportEntity, UUID> {
}
