package com.spark.backend.service;

import com.spark.backend.domain.FriendRequestStatus;
import com.spark.backend.domain.GroupInviteStatus;
import com.spark.backend.domain.GroupMemberRole;
import com.spark.backend.entity.AppUserEntity;
import com.spark.backend.entity.FriendRequestEntity;
import com.spark.backend.entity.SparkGroupEntity;
import com.spark.backend.entity.SparkGroupInviteEntity;
import com.spark.backend.entity.SparkGroupMemberEntity;
import com.spark.backend.repository.AppUserRepository;
import com.spark.backend.repository.FriendRequestRepository;
import com.spark.backend.repository.SparkGroupInviteRepository;
import com.spark.backend.repository.SparkGroupMemberRepository;
import com.spark.backend.repository.SparkGroupRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.transaction.Transactional;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

@Service
public class SocialService {
    private final AppUserRepository appUserRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final SparkGroupRepository sparkGroupRepository;
    private final SparkGroupMemberRepository sparkGroupMemberRepository;
    private final SparkGroupInviteRepository sparkGroupInviteRepository;

    public SocialService(
            AppUserRepository appUserRepository,
            FriendRequestRepository friendRequestRepository,
            SparkGroupRepository sparkGroupRepository,
            SparkGroupMemberRepository sparkGroupMemberRepository,
            SparkGroupInviteRepository sparkGroupInviteRepository
    ) {
        this.appUserRepository = appUserRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.sparkGroupRepository = sparkGroupRepository;
        this.sparkGroupMemberRepository = sparkGroupMemberRepository;
        this.sparkGroupInviteRepository = sparkGroupInviteRepository;
    }

    @Transactional
    public FriendRequestEntity sendFriendRequest(String requesterUserId, String targetPhoneNumber) {
        AppUserEntity targetUser = appUserRepository.findByPhoneNumber(normalizePhone(targetPhoneNumber))
                .orElseThrow(() -> new EntityNotFoundException("User with this phone number not found."));
        String targetUserId = targetUser.getId().toString();
        if (requesterUserId.equals(targetUserId)) {
            throw new IllegalArgumentException("You cannot send a friend request to yourself.");
        }
        FriendRequestEntity inverse = friendRequestRepository
                .findByFromUserIdAndToUserId(targetUserId, requesterUserId)
                .orElse(null);
        if (inverse != null) {
            if (inverse.getStatus() == FriendRequestStatus.ACCEPTED) {
                throw new IllegalStateException("You are already friends.");
            }
            inverse.setStatus(FriendRequestStatus.ACCEPTED);
            inverse.setRespondedAt(Instant.now());
            return friendRequestRepository.save(inverse);
        }

        FriendRequestEntity request = friendRequestRepository
                .findByFromUserIdAndToUserId(requesterUserId, targetUserId)
                .orElse(null);
        if (request == null) {
            request = new FriendRequestEntity();
            request.setFromUserId(requesterUserId);
            request.setToUserId(targetUserId);
        }
        request.setStatus(FriendRequestStatus.PENDING);
        request.setRespondedAt(null);
        return friendRequestRepository.save(request);
    }

    @Transactional
    public FriendRequestEntity respondFriendRequest(UUID requestId, String currentUserId, FriendRequestStatus nextStatus) {
        FriendRequestEntity request = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> new EntityNotFoundException("Friend request not found."));
        if (!request.getToUserId().equals(currentUserId)) {
            throw new EntityNotFoundException("Friend request not found.");
        }
        if (request.getStatus() != FriendRequestStatus.PENDING) {
            return request;
        }
        request.setStatus(nextStatus);
        request.setRespondedAt(Instant.now());
        return friendRequestRepository.save(request);
    }

    public List<FriendSummary> listFriends(String userId) {
        List<FriendRequestEntity> accepted = friendRequestRepository.findAcceptedForUser(FriendRequestStatus.ACCEPTED, userId);
        Set<String> ids = new LinkedHashSet<>();
        for (FriendRequestEntity request : accepted) {
            String friendId = request.getFromUserId().equals(userId) ? request.getToUserId() : request.getFromUserId();
            ids.add(friendId);
        }
        Map<String, AppUserEntity> users = mapUsersByIds(ids);
        return ids.stream()
                .map(friendId -> {
                    AppUserEntity user = users.get(friendId);
                    return new FriendSummary(
                            friendId,
                            user != null ? user.getDisplayName() : "Spark user",
                            user != null ? user.getPhoneNumber() : ""
                    );
                })
                .toList();
    }

    public List<FriendRequestView> listIncomingFriendRequests(String userId) {
        List<FriendRequestEntity> pending = friendRequestRepository
                .findByStatusAndToUserIdOrderByCreatedAtDesc(FriendRequestStatus.PENDING, userId);
        Set<String> fromIds = pending.stream().map(FriendRequestEntity::getFromUserId).collect(LinkedHashSet::new, Set::add, Set::addAll);
        Map<String, AppUserEntity> usersById = mapUsersByIds(fromIds);
        return pending.stream().map(request -> {
            AppUserEntity from = usersById.get(request.getFromUserId());
            return new FriendRequestView(
                    request.getId(),
                    request.getFromUserId(),
                    from != null ? from.getDisplayName() : "Spark user",
                    from != null ? from.getPhoneNumber() : "",
                    request.getCreatedAt()
            );
        }).toList();
    }

    @Transactional
    public SparkGroupEntity createGroup(String ownerUserId, String name, String description) {
        SparkGroupEntity group = new SparkGroupEntity();
        group.setOwnerUserId(ownerUserId);
        group.setName(name.trim());
        group.setDescription(description == null || description.isBlank() ? null : description.trim());
        SparkGroupEntity saved = sparkGroupRepository.save(group);

        SparkGroupMemberEntity ownerMembership = new SparkGroupMemberEntity();
        ownerMembership.setGroupId(saved.getId());
        ownerMembership.setUserId(ownerUserId);
        ownerMembership.setRole(GroupMemberRole.OWNER);
        sparkGroupMemberRepository.save(ownerMembership);
        return saved;
    }

    public List<GroupSummary> listGroupsForUser(String userId) {
        List<SparkGroupMemberEntity> memberships = sparkGroupMemberRepository.findByUserIdOrderByCreatedAtDesc(userId);
        Set<UUID> groupIds = memberships.stream().map(SparkGroupMemberEntity::getGroupId).collect(LinkedHashSet::new, Set::add, Set::addAll);
        if (groupIds.isEmpty()) {
            return List.of();
        }
        Map<UUID, SparkGroupEntity> groupsById = new HashMap<>();
        sparkGroupRepository.findAllById(groupIds).forEach(group -> groupsById.put(group.getId(), group));
        return memberships.stream()
                .map(member -> {
                    SparkGroupEntity group = groupsById.get(member.getGroupId());
                    if (group == null) {
                        return null;
                    }
                    long memberCount = sparkGroupMemberRepository.countByGroupId(group.getId());
                    return new GroupSummary(
                            group.getId(),
                            group.getName(),
                            group.getDescription(),
                            group.getOwnerUserId(),
                            member.getRole(),
                            (int) memberCount
                    );
                })
                .filter(item -> item != null)
                .toList();
    }

    public GroupDetail getGroupDetail(UUID groupId, String userId) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        SparkGroupMemberEntity me = sparkGroupMemberRepository.findByGroupIdAndUserId(groupId, userId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        List<SparkGroupMemberEntity> members = sparkGroupMemberRepository.findByGroupIdOrderByCreatedAtAsc(groupId);
        Set<String> memberIds = members.stream().map(SparkGroupMemberEntity::getUserId).collect(LinkedHashSet::new, Set::add, Set::addAll);
        Map<String, AppUserEntity> usersById = mapUsersByIds(memberIds);

        List<GroupMemberView> memberViews = members.stream()
                .map(member -> {
                    AppUserEntity user = usersById.get(member.getUserId());
                    return new GroupMemberView(
                            member.getUserId(),
                            user != null ? user.getDisplayName() : "Spark user",
                            user != null ? user.getPhoneNumber() : "",
                            member.getRole()
                    );
                })
                .toList();

        return new GroupDetail(
                group.getId(),
                group.getName(),
                group.getDescription(),
                group.getOwnerUserId(),
                me.getRole(),
                memberViews
        );
    }

    @Transactional
    public SparkGroupInviteEntity inviteFriendToGroup(UUID groupId, String inviterUserId, String friendUserId) {
        ensureGroupMember(groupId, inviterUserId);
        if (sparkGroupMemberRepository.findByGroupIdAndUserId(groupId, friendUserId).isPresent()) {
            throw new IllegalStateException("User is already a member of this group.");
        }
        if (!isFriend(inviterUserId, friendUserId)) {
            throw new IllegalStateException("You can only invite users from your friends list.");
        }
        SparkGroupInviteEntity invite = sparkGroupInviteRepository
                .findByGroupIdAndInviteeUserId(groupId, friendUserId)
                .orElse(null);
        if (invite == null) {
            invite = new SparkGroupInviteEntity();
            invite.setGroupId(groupId);
            invite.setInviteeUserId(friendUserId);
        }
        invite.setInviterUserId(inviterUserId);
        invite.setStatus(GroupInviteStatus.PENDING);
        invite.setActedAt(null);
        return sparkGroupInviteRepository.save(invite);
    }

    public List<GroupInviteView> listIncomingGroupInvites(String userId) {
        List<SparkGroupInviteEntity> invites = sparkGroupInviteRepository
                .findByInviteeUserIdAndStatusOrderByCreatedAtDesc(userId, GroupInviteStatus.PENDING);
        Set<UUID> groupIds = invites.stream().map(SparkGroupInviteEntity::getGroupId).collect(LinkedHashSet::new, Set::add, Set::addAll);
        Map<UUID, SparkGroupEntity> groupsById = new HashMap<>();
        if (!groupIds.isEmpty()) {
            sparkGroupRepository.findAllById(groupIds).forEach(group -> groupsById.put(group.getId(), group));
        }
        Set<String> inviterIds = invites.stream().map(SparkGroupInviteEntity::getInviterUserId).collect(LinkedHashSet::new, Set::add, Set::addAll);
        Map<String, AppUserEntity> usersById = mapUsersByIds(inviterIds);

        return invites.stream().map(invite -> {
            SparkGroupEntity group = groupsById.get(invite.getGroupId());
            AppUserEntity inviter = usersById.get(invite.getInviterUserId());
            return new GroupInviteView(
                    invite.getId(),
                    invite.getGroupId(),
                    group != null ? group.getName() : "Spark group",
                    invite.getInviterUserId(),
                    inviter != null ? inviter.getDisplayName() : "Spark user",
                    invite.getCreatedAt()
            );
        }).toList();
    }

    @Transactional
    public SparkGroupInviteEntity respondGroupInvite(
            UUID groupId,
            UUID inviteId,
            String userId,
            GroupInviteStatus nextStatus
    ) {
        SparkGroupInviteEntity invite = sparkGroupInviteRepository
                .findByIdAndGroupIdAndInviteeUserId(inviteId, groupId, userId)
                .orElseThrow(() -> new EntityNotFoundException("Group invite not found."));
        if (invite.getStatus() != GroupInviteStatus.PENDING) {
            return invite;
        }
        invite.setStatus(nextStatus);
        invite.setActedAt(Instant.now());
        SparkGroupInviteEntity updated = sparkGroupInviteRepository.save(invite);
        if (nextStatus == GroupInviteStatus.ACCEPTED &&
                sparkGroupMemberRepository.findByGroupIdAndUserId(groupId, userId).isEmpty()) {
            SparkGroupMemberEntity member = new SparkGroupMemberEntity();
            member.setGroupId(groupId);
            member.setUserId(userId);
            member.setRole(GroupMemberRole.MEMBER);
            sparkGroupMemberRepository.save(member);
        }
        return updated;
    }

    @Transactional
    public void removeMember(UUID groupId, String ownerUserId, String targetUserId) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        if (!group.getOwnerUserId().equals(ownerUserId)) {
            throw new IllegalStateException("Only the group owner can remove members.");
        }
        if (ownerUserId.equals(targetUserId)) {
            throw new IllegalArgumentException("Owner cannot remove themselves.");
        }
        SparkGroupMemberEntity member = sparkGroupMemberRepository
                .findByGroupIdAndUserId(groupId, targetUserId)
                .orElseThrow(() -> new EntityNotFoundException("Member not found."));
        sparkGroupMemberRepository.delete(member);
    }

    @Transactional
    public void unfriend(String userId, String friendUserId) {
        Optional<FriendRequestEntity> direct = friendRequestRepository
                .findByFromUserIdAndToUserId(userId, friendUserId);
        Optional<FriendRequestEntity> inverse = friendRequestRepository
                .findByFromUserIdAndToUserId(friendUserId, userId);
        direct.ifPresent(friendRequestRepository::delete);
        inverse.ifPresent(friendRequestRepository::delete);
    }

    @Transactional
    public SparkGroupInviteEntity nudgePendingInvite(UUID groupId, String ownerUserId, String inviteeUserId) {
        ensureGroupMember(groupId, ownerUserId);
        SparkGroupInviteEntity invite = sparkGroupInviteRepository
                .findByGroupIdAndInviteeUserId(groupId, inviteeUserId)
                .orElseThrow(() -> new EntityNotFoundException("Pending invite not found."));
        if (invite.getStatus() != GroupInviteStatus.PENDING) {
            throw new IllegalStateException("Invite is no longer pending.");
        }
        invite.setInviterUserId(invite.getInviterUserId());
        return sparkGroupInviteRepository.save(invite);
    }

    private boolean isFriend(String userA, String userB) {
        Optional<FriendRequestEntity> direct = friendRequestRepository.findByFromUserIdAndToUserId(userA, userB);
        if (direct.isPresent() && direct.get().getStatus() == FriendRequestStatus.ACCEPTED) {
            return true;
        }
        Optional<FriendRequestEntity> inverse = friendRequestRepository.findByFromUserIdAndToUserId(userB, userA);
        return inverse.isPresent() && inverse.get().getStatus() == FriendRequestStatus.ACCEPTED;
    }

    private void ensureGroupMember(UUID groupId, String userId) {
        sparkGroupMemberRepository.findByGroupIdAndUserId(groupId, userId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
    }

    private Map<String, AppUserEntity> mapUsersByIds(Set<String> ids) {
        Map<String, AppUserEntity> map = new HashMap<>();
        if (ids.isEmpty()) {
            return map;
        }
        List<UUID> uuids = ids.stream()
                .map(this::safeUuid)
                .filter(item -> item != null)
                .toList();
        if (!uuids.isEmpty()) {
            appUserRepository.findAllById(uuids).forEach(user -> map.put(user.getId().toString(), user));
        }
        return map;
    }

    private UUID safeUuid(String value) {
        try {
            return UUID.fromString(value);
        } catch (Exception ignored) {
            return null;
        }
    }

    private String normalizePhone(String raw) {
        String clean = raw.replaceAll("[^0-9+]", "");
        if (clean.isBlank()) {
            throw new IllegalArgumentException("Phone number is required.");
        }
        if (clean.startsWith("+")) {
            return clean;
        }
        String digits = clean.replaceAll("[^0-9]", "");
        if (digits.length() == 10) {
            return "+91" + digits;
        }
        return "+" + digits;
    }

    public record FriendSummary(
            String userId,
            String displayName,
            String phoneNumber
    ) {
    }

    public record FriendRequestView(
            UUID requestId,
            String fromUserId,
            String displayName,
            String phoneNumber,
            Instant createdAt
    ) {
    }

    public record GroupSummary(
            UUID groupId,
            String name,
            String description,
            String ownerUserId,
            GroupMemberRole myRole,
            int memberCount
    ) {
    }

    public record GroupMemberView(
            String userId,
            String displayName,
            String phoneNumber,
            GroupMemberRole role
    ) {
    }

    public record GroupDetail(
            UUID groupId,
            String name,
            String description,
            String ownerUserId,
            GroupMemberRole myRole,
            List<GroupMemberView> members
    ) {
    }

    public record GroupInviteView(
            UUID inviteId,
            UUID groupId,
            String groupName,
            String inviterUserId,
            String inviterName,
            Instant createdAt
    ) {
    }
}

