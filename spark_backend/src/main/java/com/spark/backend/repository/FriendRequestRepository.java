package com.spark.backend.repository;

import com.spark.backend.domain.FriendRequestStatus;
import com.spark.backend.entity.FriendRequestEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FriendRequestRepository extends JpaRepository<FriendRequestEntity, UUID> {
    Optional<FriendRequestEntity> findByFromUserIdAndToUserId(String fromUserId, String toUserId);

    List<FriendRequestEntity> findByStatusAndToUserIdOrderByCreatedAtDesc(FriendRequestStatus status, String toUserId);

    List<FriendRequestEntity> findByStatusAndFromUserIdOrderByCreatedAtDesc(FriendRequestStatus status, String fromUserId);

    @Query("""
            select r
            from FriendRequestEntity r
            where r.status = :status
              and (r.fromUserId = :userId or r.toUserId = :userId)
            order by r.updatedAt desc
            """)
    List<FriendRequestEntity> findAcceptedForUser(
            @Param("status") FriendRequestStatus status,
            @Param("userId") String userId
    );

    @Transactional
    @Modifying
    @Query("delete from FriendRequestEntity r where r.fromUserId = :userId or r.toUserId = :userId")
    void deleteByUser(@Param("userId") String userId);
}
