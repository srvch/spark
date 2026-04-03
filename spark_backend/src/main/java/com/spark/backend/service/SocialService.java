package com.spark.backend.service;

import com.spark.backend.domain.FriendRequestStatus;
import com.spark.backend.domain.GroupInviteStatus;
import com.spark.backend.domain.GroupMemberRole;
import com.spark.backend.domain.SparkStatus;
import com.spark.backend.entity.*;
import com.spark.backend.repository.*;
import jakarta.persistence.EntityNotFoundException;
import jakarta.transaction.Transactional;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;

@Service
public class SocialService {
    private final AppUserRepository appUserRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final SparkGroupRepository sparkGroupRepository;
    private final SparkGroupMemberRepository sparkGroupMemberRepository;
    private final SparkGroupInviteRepository sparkGroupInviteRepository;
    private final SparkEventRepository sparkEventRepository;
    private final UserBlockRepository userBlockRepository;
    private final UserReportRepository userReportRepository;

    public SocialService(
            AppUserRepository appUserRepository,
            FriendRequestRepository friendRequestRepository,
            SparkGroupRepository sparkGroupRepository,
            SparkGroupMemberRepository sparkGroupMemberRepository,
            SparkGroupInviteRepository sparkGroupInviteRepository,
            SparkEventRepository sparkEventRepository,
            UserBlockRepository userBlockRepository,
            UserReportRepository userReportRepository
    ) {
        this.appUserRepository = appUserRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.sparkGroupRepository = sparkGroupRepository;
        this.sparkGroupMemberRepository = sparkGroupMemberRepository;
        this.sparkGroupInviteRepository = sparkGroupInviteRepository;
        this.sparkEventRepository = sparkEventRepository;
        this.userBlockRepository = userBlockRepository;
        this.userReportRepository = userReportRepository;
    }

    // ─── Friend Requests ────────────────────────────────────────────────────

    @Transactional
    public FriendRequestEntity sendFriendRequest(String requesterUserId, String targetPhoneNumber, String message) {
        AppUserEntity targetUser = appUserRepository.findByPhoneNumber(normalizePhone(targetPhoneNumber))
                .orElseThrow(() -> new EntityNotFoundException("User with this phone number not found."));
        String targetUserId = targetUser.getId().toString();
        if (requesterUserId.equals(targetUserId)) {
            throw new IllegalArgumentException("You cannot send a friend request to yourself.");
        }
        if (userBlockRepository.existsByBlockerUserIdAndBlockedUserId(targetUserId, requesterUserId)) {
            throw new IllegalStateException("Unable to send request.");
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
        if (message != null && !message.isBlank()) {
            request.setMessage(message.trim());
        }
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

    @Transactional
    public void cancelFriendRequest(UUID requestId, String userId) {
        FriendRequestEntity request = friendRequestRepository.findById(requestId)
                .orElseThrow(() -> new EntityNotFoundException("Friend request not found."));
        if (!request.getFromUserId().equals(userId)) {
            throw new EntityNotFoundException("Friend request not found.");
        }
        if (request.getStatus() != FriendRequestStatus.PENDING) {
            throw new IllegalStateException("Request is no longer pending.");
        }
        friendRequestRepository.delete(request);
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
                            user != null ? user.getPhoneNumber() : "",
                            user != null ? user.getAvailabilityStatus() : "NONE"
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
                    request.getCreatedAt(),
                    request.getMessage()
            );
        }).toList();
    }

    public List<OutgoingFriendRequestView> listOutgoingPendingRequests(String userId) {
        List<FriendRequestEntity> pending = friendRequestRepository
                .findByStatusAndFromUserIdOrderByCreatedAtDesc(FriendRequestStatus.PENDING, userId);
        Set<String> toIds = pending.stream().map(FriendRequestEntity::getToUserId).collect(LinkedHashSet::new, Set::add, Set::addAll);
        Map<String, AppUserEntity> usersById = mapUsersByIds(toIds);
        return pending.stream().map(request -> {
            AppUserEntity to = usersById.get(request.getToUserId());
            return new OutgoingFriendRequestView(
                    request.getId(),
                    request.getToUserId(),
                    to != null ? to.getDisplayName() : "Spark user",
                    to != null ? to.getPhoneNumber() : "",
                    request.getCreatedAt(),
                    request.getMessage()
            );
        }).toList();
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

    // ─── Friend Suggestions + Contact Matching ──────────────────────────────

    public List<FriendSuggestionView> suggestFriends(String userId) {
        List<SparkGroupMemberEntity> myMemberships = sparkGroupMemberRepository.findByUserIdOrderByCreatedAtDesc(userId);
        if (myMemberships.isEmpty()) {
            return List.of();
        }
        Set<String> friendIds = new HashSet<>();
        for (FriendRequestEntity r : friendRequestRepository.findAcceptedForUser(FriendRequestStatus.ACCEPTED, userId)) {
            friendIds.add(r.getFromUserId().equals(userId) ? r.getToUserId() : r.getFromUserId());
        }

        Map<String, Integer> mutualCount = new LinkedHashMap<>();
        for (SparkGroupMemberEntity myMembership : myMemberships) {
            List<SparkGroupMemberEntity> groupMembers = sparkGroupMemberRepository.findByGroupIdOrderByCreatedAtAsc(myMembership.getGroupId());
            for (SparkGroupMemberEntity gm : groupMembers) {
                String mid = gm.getUserId();
                if (!mid.equals(userId) && !friendIds.contains(mid)) {
                    mutualCount.merge(mid, 1, Integer::sum);
                }
            }
        }
        if (mutualCount.isEmpty()) {
            return List.of();
        }

        Map<String, AppUserEntity> users = mapUsersByIds(mutualCount.keySet());
        return mutualCount.entrySet().stream()
                .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
                .limit(10)
                .map(entry -> {
                    AppUserEntity u = users.get(entry.getKey());
                    return new FriendSuggestionView(
                            entry.getKey(),
                            u != null ? u.getDisplayName() : "Spark user",
                            u != null ? u.getPhoneNumber() : "",
                            entry.getValue()
                    );
                })
                .toList();
    }

    public List<MatchedContactView> matchContacts(String userId, List<String> phoneNumbers) {
        Set<String> friendIds = new HashSet<>();
        for (FriendRequestEntity r : friendRequestRepository.findAcceptedForUser(FriendRequestStatus.ACCEPTED, userId)) {
            friendIds.add(r.getFromUserId().equals(userId) ? r.getToUserId() : r.getFromUserId());
        }
        List<MatchedContactView> results = new ArrayList<>();
        for (String rawPhone : phoneNumbers) {
            String normalized;
            try {
                normalized = normalizePhone(rawPhone);
            } catch (Exception ignored) {
                continue;
            }
            appUserRepository.findByPhoneNumber(normalized).ifPresent(user -> {
                String uid = user.getId().toString();
                if (!uid.equals(userId)) {
                    results.add(new MatchedContactView(uid, user.getDisplayName(), user.getPhoneNumber(), friendIds.contains(uid)));
                }
            });
        }
        return results;
    }

    // ─── Availability ────────────────────────────────────────────────────────

    @Transactional
    public void setAvailability(String userId, String status) {
        if (!status.equals("NONE") && !status.equals("OPEN")) {
            throw new IllegalArgumentException("Status must be NONE or OPEN.");
        }
        AppUserEntity user = appUserRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new EntityNotFoundException("User not found."));
        user.setAvailabilityStatus(status);
        appUserRepository.save(user);
    }

    // ─── Block / Report ──────────────────────────────────────────────────────

    @Transactional
    public void blockUser(String userId, String targetUserId) {
        if (userId.equals(targetUserId)) {
            throw new IllegalArgumentException("You cannot block yourself.");
        }
        if (!userBlockRepository.existsByBlockerUserIdAndBlockedUserId(userId, targetUserId)) {
            UserBlockEntity block = new UserBlockEntity();
            block.setBlockerUserId(userId);
            block.setBlockedUserId(targetUserId);
            userBlockRepository.save(block);
        }
        unfriend(userId, targetUserId);
    }

    @Transactional
    public void reportUser(String userId, String targetUserId, String reason) {
        if (userId.equals(targetUserId)) {
            throw new IllegalArgumentException("You cannot report yourself.");
        }
        UserReportEntity report = new UserReportEntity();
        report.setReporterUserId(userId);
        report.setReportedUserId(targetUserId);
        report.setReason(reason);
        userReportRepository.save(report);
    }

    // ─── Groups ──────────────────────────────────────────────────────────────

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

    @Transactional
    public SparkGroupEntity updateGroup(UUID groupId, String userId, String name, String description) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        SparkGroupMemberEntity member = sparkGroupMemberRepository.findByGroupIdAndUserId(groupId, userId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        if (member.getRole() == GroupMemberRole.MEMBER) {
            throw new IllegalStateException("Only the group owner or admin can edit the group.");
        }
        group.setName(name.trim());
        group.setDescription(description == null || description.isBlank() ? null : description.trim());
        return sparkGroupRepository.save(group);
    }

    @Transactional
    public void archiveGroup(UUID groupId, String userId) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        if (!group.getOwnerUserId().equals(userId)) {
            throw new IllegalStateException("Only the group owner can archive the group.");
        }
        group.setArchived(true);
        group.setArchivedAt(Instant.now());
        sparkGroupRepository.save(group);
    }

    @Transactional
    public void unarchiveGroup(UUID groupId, String userId) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        if (!group.getOwnerUserId().equals(userId)) {
            throw new IllegalStateException("Only the group owner can unarchive the group.");
        }
        group.setArchived(false);
        group.setArchivedAt(null);
        sparkGroupRepository.save(group);
    }

    @Transactional
    public void leaveGroup(UUID groupId, String userId) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        if (group.getOwnerUserId().equals(userId)) {
            throw new IllegalStateException("The group owner cannot leave. Transfer ownership or delete the group.");
        }
        SparkGroupMemberEntity member = sparkGroupMemberRepository
                .findByGroupIdAndUserId(groupId, userId)
                .orElseThrow(() -> new EntityNotFoundException("You are not a member of this group."));
        sparkGroupMemberRepository.delete(member);
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
                    if (group == null || group.isArchived()) {
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
                memberViews,
                group.isArchived()
        );
    }

    // ─── Group Members ────────────────────────────────────────────────────────

    @Transactional
    public SparkGroupMemberEntity promoteToAdmin(UUID groupId, String ownerId, String targetUserId) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        if (!group.getOwnerUserId().equals(ownerId)) {
            throw new IllegalStateException("Only the group owner can promote members.");
        }
        SparkGroupMemberEntity member = sparkGroupMemberRepository
                .findByGroupIdAndUserId(groupId, targetUserId)
                .orElseThrow(() -> new EntityNotFoundException("Member not found."));
        if (member.getRole() != GroupMemberRole.MEMBER) {
            throw new IllegalStateException("Member is already an owner or admin.");
        }
        member.setRole(GroupMemberRole.ADMIN);
        return sparkGroupMemberRepository.save(member);
    }

    @Transactional
    public SparkGroupMemberEntity demoteToMember(UUID groupId, String ownerId, String targetUserId) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        if (!group.getOwnerUserId().equals(ownerId)) {
            throw new IllegalStateException("Only the group owner can demote admins.");
        }
        SparkGroupMemberEntity member = sparkGroupMemberRepository
                .findByGroupIdAndUserId(groupId, targetUserId)
                .orElseThrow(() -> new EntityNotFoundException("Member not found."));
        if (member.getRole() != GroupMemberRole.ADMIN) {
            throw new IllegalStateException("Member is not an admin.");
        }
        member.setRole(GroupMemberRole.MEMBER);
        return sparkGroupMemberRepository.save(member);
    }

    @Transactional
    public void removeMember(UUID groupId, String ownerUserId, String targetUserId) {
        SparkGroupEntity group = sparkGroupRepository.findById(groupId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        SparkGroupMemberEntity callerMember = sparkGroupMemberRepository
                .findByGroupIdAndUserId(groupId, ownerUserId)
                .orElseThrow(() -> new EntityNotFoundException("Group not found."));
        if (callerMember.getRole() == GroupMemberRole.MEMBER) {
            throw new IllegalStateException("Only the group owner or admin can remove members.");
        }
        if (ownerUserId.equals(targetUserId)) {
            throw new IllegalArgumentException("You cannot remove yourself.");
        }
        SparkGroupMemberEntity member = sparkGroupMemberRepository
                .findByGroupIdAndUserId(groupId, targetUserId)
                .orElseThrow(() -> new EntityNotFoundException("Member not found."));
        if (member.getRole() == GroupMemberRole.OWNER) {
            throw new IllegalStateException("Cannot remove the group owner.");
        }
        sparkGroupMemberRepository.delete(member);
    }

    // ─── Group Invites ────────────────────────────────────────────────────────

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

    public List<OutgoingGroupInviteView> listPendingGroupInvites(UUID groupId, String userId) {
        ensureGroupMember(groupId, userId);
        List<SparkGroupInviteEntity> invites = sparkGroupInviteRepository
                .findByGroupIdAndStatusOrderByCreatedAtDesc(groupId, GroupInviteStatus.PENDING);
        Set<String> inviteeIds = invites.stream().map(SparkGroupInviteEntity::getInviteeUserId).collect(LinkedHashSet::new, Set::add, Set::addAll);
        Map<String, AppUserEntity> usersById = mapUsersByIds(inviteeIds);
        return invites.stream().map(invite -> {
            AppUserEntity invitee = usersById.get(invite.getInviteeUserId());
            return new OutgoingGroupInviteView(
                    invite.getId(),
                    invite.getGroupId(),
                    invite.getInviteeUserId(),
                    invitee != null ? invitee.getDisplayName() : "Spark user",
                    invitee != null ? invitee.getPhoneNumber() : "",
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
    public SparkGroupInviteEntity nudgePendingInvite(UUID groupId, String callerUserId, String inviteeUserId) {
        ensureGroupMember(groupId, callerUserId);
        SparkGroupInviteEntity invite = sparkGroupInviteRepository
                .findByGroupIdAndInviteeUserId(groupId, inviteeUserId)
                .orElseThrow(() -> new EntityNotFoundException("Pending invite not found."));
        if (invite.getStatus() != GroupInviteStatus.PENDING) {
            throw new IllegalStateException("Invite is no longer pending.");
        }
        return sparkGroupInviteRepository.save(invite);
    }

    // ─── Group Activity ────────────────────────────────────────────────────────

    public List<GroupActivityEvent> getGroupActivity(UUID groupId, String userId) {
        ensureGroupMember(groupId, userId);
        List<SparkGroupMemberEntity> members = sparkGroupMemberRepository.findByGroupIdOrderByCreatedAtAsc(groupId);
        Set<String> memberIds = new LinkedHashSet<>();
        members.forEach(m -> memberIds.add(m.getUserId()));
        Map<String, AppUserEntity> usersById = mapUsersByIds(memberIds);

        List<GroupActivityEvent> events = new ArrayList<>();

        List<SparkGroupInviteEntity> accepted = sparkGroupInviteRepository
                .findByGroupIdAndStatusOrderByCreatedAtDesc(groupId, GroupInviteStatus.ACCEPTED);
        for (SparkGroupInviteEntity invite : accepted) {
            AppUserEntity invitee = usersById.get(invite.getInviteeUserId());
            events.add(new GroupActivityEvent(
                    invite.getId().toString(),
                    "join",
                    invite.getInviteeUserId(),
                    invitee != null ? invitee.getDisplayName() : "Spark user",
                    invite.getActedAt() != null ? invite.getActedAt() : invite.getCreatedAt()
            ));
        }

        if (!memberIds.isEmpty()) {
            List<SparkEventEntity> sparks = sparkEventRepository.findByHostUserIdInOrderByStartsAtDesc(memberIds);
            for (SparkEventEntity spark : sparks.stream().limit(20).toList()) {
                AppUserEntity host = usersById.get(spark.getHostUserId());
                events.add(new GroupActivityEvent(
                        spark.getId().toString(),
                        "spark",
                        spark.getHostUserId(),
                        host != null ? host.getDisplayName() : "Spark user",
                        spark.getStartsAt()
                ));
            }
        }

        events.sort((a, b) -> b.timestamp().compareTo(a.timestamp()));
        return events.stream().limit(30).toList();
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

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

    // ─── View Records ─────────────────────────────────────────────────────────

    public record FriendSummary(
            String userId,
            String displayName,
            String phoneNumber,
            String availabilityStatus
    ) {}

    public record FriendRequestView(
            UUID requestId,
            String fromUserId,
            String displayName,
            String phoneNumber,
            Instant createdAt,
            String message
    ) {}

    public record OutgoingFriendRequestView(
            UUID requestId,
            String toUserId,
            String displayName,
            String phoneNumber,
            Instant createdAt,
            String message
    ) {}

    public record FriendSuggestionView(
            String userId,
            String displayName,
            String phoneNumber,
            int mutualGroupCount
    ) {}

    public record MatchedContactView(
            String userId,
            String displayName,
            String phoneNumber,
            boolean alreadyFriend
    ) {}

    public record GroupSummary(
            UUID groupId,
            String name,
            String description,
            String ownerUserId,
            GroupMemberRole myRole,
            int memberCount
    ) {}

    public record GroupMemberView(
            String userId,
            String displayName,
            String phoneNumber,
            GroupMemberRole role
    ) {}

    public record GroupDetail(
            UUID groupId,
            String name,
            String description,
            String ownerUserId,
            GroupMemberRole myRole,
            List<GroupMemberView> members,
            boolean archived
    ) {}

    public record GroupInviteView(
            UUID inviteId,
            UUID groupId,
            String groupName,
            String inviterUserId,
            String inviterName,
            Instant createdAt
    ) {}

    public record OutgoingGroupInviteView(
            UUID inviteId,
            UUID groupId,
            String inviteeUserId,
            String inviteeName,
            String inviteePhone,
            Instant createdAt
    ) {}

    public record GroupActivityEvent(
            String eventId,
            String type,
            String userId,
            String displayName,
            Instant timestamp
    ) {}
}
