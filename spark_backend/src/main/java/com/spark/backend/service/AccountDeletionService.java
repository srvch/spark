package com.spark.backend.service;

import com.spark.backend.entity.SparkEventEntity;
import com.spark.backend.entity.SparkGroupEntity;
import com.spark.backend.repository.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * Handles full cascade deletion of a user account.
 * Redis cleanup is performed first (non-transactional), then all DB data
 * is wiped in a single transaction.
 */
@Service
public class AccountDeletionService {

    private static final Logger log = LoggerFactory.getLogger(AccountDeletionService.class);

    private final AppUserRepository appUserRepository;
    private final SparkEventRepository sparkEventRepository;
    private final SparkParticipantRepository sparkParticipantRepository;
    private final UserDeviceTokenRepository userDeviceTokenRepository;
    private final UserNotificationRepository userNotificationRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final SparkInviteRepository sparkInviteRepository;
    private final SparkGroupRepository sparkGroupRepository;
    private final SparkGroupMemberRepository sparkGroupMemberRepository;
    private final SparkGroupInviteRepository sparkGroupInviteRepository;
    private final UserBlockRepository userBlockRepository;
    private final ChatRepository chatRepository;
    private final LiveSparkCacheService liveSparkCacheService;

    public AccountDeletionService(
            AppUserRepository appUserRepository,
            SparkEventRepository sparkEventRepository,
            SparkParticipantRepository sparkParticipantRepository,
            UserDeviceTokenRepository userDeviceTokenRepository,
            UserNotificationRepository userNotificationRepository,
            FriendRequestRepository friendRequestRepository,
            SparkInviteRepository sparkInviteRepository,
            SparkGroupRepository sparkGroupRepository,
            SparkGroupMemberRepository sparkGroupMemberRepository,
            SparkGroupInviteRepository sparkGroupInviteRepository,
            UserBlockRepository userBlockRepository,
            ChatRepository chatRepository,
            LiveSparkCacheService liveSparkCacheService
    ) {
        this.appUserRepository = appUserRepository;
        this.sparkEventRepository = sparkEventRepository;
        this.sparkParticipantRepository = sparkParticipantRepository;
        this.userDeviceTokenRepository = userDeviceTokenRepository;
        this.userNotificationRepository = userNotificationRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.sparkInviteRepository = sparkInviteRepository;
        this.sparkGroupRepository = sparkGroupRepository;
        this.sparkGroupMemberRepository = sparkGroupMemberRepository;
        this.sparkGroupInviteRepository = sparkGroupInviteRepository;
        this.userBlockRepository = userBlockRepository;
        this.chatRepository = chatRepository;
        this.liveSparkCacheService = liveSparkCacheService;
    }

    /**
     * Deletes the account for the given userId.
     * Step 1: Evict hosted sparks from Redis (best-effort, non-transactional).
     * Step 2: Delete all DB data in a single transaction.
     */
    public void deleteAccount(String userId) {
        log.info("[AccountDeletion] Starting deletion for userId={}", userId);

        // Step 1 — Evict hosted sparks from Redis geo-index (before DB deletion)
        List<SparkEventEntity> hostedSparks = sparkEventRepository.findByHostUserId(userId);
        for (SparkEventEntity spark : hostedSparks) {
            try {
                liveSparkCacheService.remove(spark.getId());
            } catch (Exception e) {
                log.warn("[AccountDeletion] Could not remove spark {} from cache: {}", spark.getId(), e.getMessage());
            }
        }

        // Step 2 — Cascade delete in DB
        deleteAccountData(userId, hostedSparks);
        log.info("[AccountDeletion] Completed deletion for userId={}", userId);
    }

    @Transactional
    protected void deleteAccountData(String userId, List<SparkEventEntity> hostedSparks) {
        // 1. Device tokens
        userDeviceTokenRepository.deleteByUserId(userId);

        // 2. Notifications
        userNotificationRepository.deleteByRecipientUserId(userId);

        // 3. Chat messages sent by this user
        chatRepository.deleteBySenderId(userId);

        // 4. Spark invites (sent or received)
        sparkInviteRepository.deleteByUser(userId);

        // 5. Group invites received by this user
        sparkGroupInviteRepository.deleteByInviteeUserId(userId);

        // 6. Group memberships (as a member)
        sparkGroupMemberRepository.deleteByUserId(userId);

        // 7. Groups owned by this user — cascade members and invites first
        List<SparkGroupEntity> ownedGroups = sparkGroupRepository.findByOwnerUserId(userId);
        for (SparkGroupEntity group : ownedGroups) {
            sparkGroupMemberRepository.deleteByGroupId(group.getId());
            sparkGroupInviteRepository.deleteByGroupId(group.getId());
        }
        if (!ownedGroups.isEmpty()) {
            sparkGroupRepository.deleteAll(ownedGroups);
        }

        // 8. Friend requests (sent or received)
        friendRequestRepository.deleteByUser(userId);

        // 9. User blocks (blocker or blocked)
        userBlockRepository.deleteByUser(userId);

        // 10. Hosted sparks — delete participants first, then events
        for (SparkEventEntity spark : hostedSparks) {
            sparkParticipantRepository.deleteBySparkId(spark.getId());
        }
        if (!hostedSparks.isEmpty()) {
            sparkEventRepository.deleteAll(hostedSparks);
        }

        // 11. Participant records where user joined others' sparks
        sparkParticipantRepository.deleteByUserId(userId);

        // 12. Delete the user account itself
        appUserRepository.deleteById(UUID.fromString(userId));
    }
}
