package com.spark.backend.repository;

import com.spark.backend.entity.ChatMessageEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Repository
public interface ChatRepository extends JpaRepository<ChatMessageEntity, UUID> {
    Page<ChatMessageEntity> findBySparkIdOrderByCreatedAtDesc(UUID sparkId, Pageable pageable);

    @Transactional
    @Modifying
    @Query("delete from ChatMessageEntity c where c.senderId = :senderId")
    void deleteBySenderId(@Param("senderId") String senderId);
}
