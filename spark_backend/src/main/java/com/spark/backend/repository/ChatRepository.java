package com.spark.backend.repository;

import com.spark.backend.entity.ChatMessageEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface ChatRepository extends JpaRepository<ChatMessageEntity, UUID> {
    Page<ChatMessageEntity> findBySparkIdOrderByCreatedAtDesc(UUID sparkId, Pageable pageable);
}
