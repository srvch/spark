package com.spark.backend.controller;

import com.spark.backend.domain.FriendRequestStatus;
import com.spark.backend.domain.GroupInviteStatus;
import com.spark.backend.security.CurrentUser;
import com.spark.backend.service.SocialService;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/social")
public class SocialController {
    private final SocialService socialService;

    public SocialController(SocialService socialService) {
        this.socialService = socialService;
    }

    // ─── Friend Requests ─────────────────────────────────────────────────────

    @PostMapping("/friends/request")
    @ResponseStatus(HttpStatus.CREATED)
    public FriendRequestResponse sendFriendRequest(
            Authentication authentication,
            @Valid @RequestBody SendFriendRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var saved = socialService.sendFriendRequest(currentUser.userId(), request.phoneNumber(), request.message());
        return toFriendRequestResponse(saved);
    }

    @GetMapping("/friends")
    public List<FriendSummaryResponse> friends(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listFriends(currentUser.userId()).stream()
                .map(friend -> new FriendSummaryResponse(
                        friend.userId(),
                        friend.displayName(),
                        friend.phoneNumber(),
                        friend.availabilityStatus()
                ))
                .toList();
    }

    @GetMapping("/friends/requests/incoming")
    public List<FriendIncomingRequestResponse> incomingFriendRequests(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listIncomingFriendRequests(currentUser.userId()).stream()
                .map(request -> new FriendIncomingRequestResponse(
                        request.requestId(),
                        request.fromUserId(),
                        request.displayName(),
                        request.phoneNumber(),
                        request.createdAt(),
                        request.message()
                ))
                .toList();
    }

    @GetMapping("/friends/requests/outgoing")
    public List<OutgoingFriendRequestResponse> outgoingFriendRequests(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listOutgoingPendingRequests(currentUser.userId()).stream()
                .map(r -> new OutgoingFriendRequestResponse(
                        r.requestId(),
                        r.toUserId(),
                        r.displayName(),
                        r.phoneNumber(),
                        r.createdAt(),
                        r.message()
                ))
                .toList();
    }

    @PostMapping("/friends/requests/{requestId}/respond")
    public FriendRequestResponse respondFriendRequest(
            Authentication authentication,
            @PathVariable UUID requestId,
            @Valid @RequestBody FriendRequestRespondRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        if (request.status() == FriendRequestStatus.PENDING) {
            throw new IllegalArgumentException("Status must be ACCEPTED or DECLINED.");
        }
        var updated = socialService.respondFriendRequest(requestId, currentUser.userId(), request.status());
        return toFriendRequestResponse(updated);
    }

    @DeleteMapping("/friends/requests/{requestId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelFriendRequest(Authentication authentication, @PathVariable UUID requestId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.cancelFriendRequest(requestId, currentUser.userId());
    }

    @DeleteMapping("/friends/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unfriend(Authentication authentication, @PathVariable String userId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.unfriend(currentUser.userId(), userId);
    }

    // ─── Suggestions + Contact Matching ──────────────────────────────────────

    @GetMapping("/friends/suggestions")
    public List<FriendSuggestionResponse> friendSuggestions(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.suggestFriends(currentUser.userId()).stream()
                .map(s -> new FriendSuggestionResponse(
                        s.userId(), s.displayName(), s.phoneNumber(), s.mutualGroupCount()
                ))
                .toList();
    }

    @PostMapping("/contacts/match")
    public List<MatchedContactResponse> matchContacts(
            Authentication authentication,
            @Valid @RequestBody ContactMatchRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.matchContacts(currentUser.userId(), request.phoneNumbers()).stream()
                .map(c -> new MatchedContactResponse(
                        c.userId(), c.displayName(), c.phoneNumber(), c.alreadyFriend()
                ))
                .toList();
    }

    // ─── Availability ─────────────────────────────────────────────────────────

    @PutMapping("/availability")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void setAvailability(
            Authentication authentication,
            @Valid @RequestBody SetAvailabilityRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.setAvailability(currentUser.userId(), request.status());
    }

    // ─── Block / Report ───────────────────────────────────────────────────────

    @PostMapping("/block/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void blockUser(Authentication authentication, @PathVariable String userId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.blockUser(currentUser.userId(), userId);
    }

    @PostMapping("/report/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reportUser(
            Authentication authentication,
            @PathVariable String userId,
            @Valid @RequestBody ReportUserRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.reportUser(currentUser.userId(), userId, request.reason());
    }

    // ─── Groups ───────────────────────────────────────────────────────────────

    @PostMapping("/groups")
    @ResponseStatus(HttpStatus.CREATED)
    public GroupSummaryResponse createGroup(
            Authentication authentication,
            @Valid @RequestBody CreateGroupRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var group = socialService.createGroup(currentUser.userId(), request.name(), request.description());
        return new GroupSummaryResponse(group.getId(), group.getName(), group.getDescription(),
                group.getOwnerUserId(), "OWNER", 1, false);
    }

    @GetMapping("/groups")
    public List<GroupSummaryResponse> groups(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listGroupsForUser(currentUser.userId()).stream()
                .map(group -> new GroupSummaryResponse(
                        group.groupId(), group.name(), group.description(),
                        group.ownerUserId(), group.myRole().name(), group.memberCount(), false
                ))
                .toList();
    }

    @GetMapping("/groups/{groupId}")
    public GroupDetailResponse groupDetail(Authentication authentication, @PathVariable UUID groupId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var group = socialService.getGroupDetail(groupId, currentUser.userId());
        var members = group.members().stream()
                .map(member -> new GroupMemberResponse(
                        member.userId(), member.displayName(), member.phoneNumber(), member.role().name()
                ))
                .toList();
        return new GroupDetailResponse(
                group.groupId(), group.name(), group.description(),
                group.ownerUserId(), group.myRole().name(), members, group.archived()
        );
    }

    @PatchMapping("/groups/{groupId}")
    public GroupSummaryResponse updateGroup(
            Authentication authentication,
            @PathVariable UUID groupId,
            @Valid @RequestBody UpdateGroupRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var group = socialService.updateGroup(groupId, currentUser.userId(), request.name(), request.description());
        long memberCount = 0;
        return new GroupSummaryResponse(
                group.getId(), group.getName(), group.getDescription(),
                group.getOwnerUserId(), "OWNER", (int) memberCount, group.isArchived()
        );
    }

    @PostMapping("/groups/{groupId}/archive")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void archiveGroup(Authentication authentication, @PathVariable UUID groupId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.archiveGroup(groupId, currentUser.userId());
    }

    @PostMapping("/groups/{groupId}/unarchive")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unarchiveGroup(Authentication authentication, @PathVariable UUID groupId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.unarchiveGroup(groupId, currentUser.userId());
    }

    @PostMapping("/groups/{groupId}/leave")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leaveGroup(Authentication authentication, @PathVariable UUID groupId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.leaveGroup(groupId, currentUser.userId());
    }

    @GetMapping("/groups/{groupId}/activity")
    public List<GroupActivityResponse> groupActivity(
            Authentication authentication,
            @PathVariable UUID groupId
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.getGroupActivity(groupId, currentUser.userId()).stream()
                .map(e -> new GroupActivityResponse(e.eventId(), e.type(), e.userId(), e.displayName(), e.timestamp()))
                .toList();
    }

    // ─── Group Members ─────────────────────────────────────────────────────────

    @PostMapping("/groups/{groupId}/members/{userId}/promote")
    public GroupMemberResponse promoteToAdmin(
            Authentication authentication,
            @PathVariable UUID groupId,
            @PathVariable String userId
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var member = socialService.promoteToAdmin(groupId, currentUser.userId(), userId);
        return new GroupMemberResponse(member.getUserId(), "", "", member.getRole().name());
    }

    @PostMapping("/groups/{groupId}/members/{userId}/demote")
    public GroupMemberResponse demoteToMember(
            Authentication authentication,
            @PathVariable UUID groupId,
            @PathVariable String userId
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var member = socialService.demoteToMember(groupId, currentUser.userId(), userId);
        return new GroupMemberResponse(member.getUserId(), "", "", member.getRole().name());
    }

    @DeleteMapping("/groups/{groupId}/members/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeMember(
            Authentication authentication,
            @PathVariable UUID groupId,
            @PathVariable String userId
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        socialService.removeMember(groupId, currentUser.userId(), userId);
    }

    @PostMapping("/groups/{groupId}/members/{userId}/nudge")
    @ResponseStatus(HttpStatus.OK)
    public GroupInviteResponse nudgePendingMember(
            Authentication authentication,
            @PathVariable UUID groupId,
            @PathVariable String userId
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var invite = socialService.nudgePendingInvite(groupId, currentUser.userId(), userId);
        return new GroupInviteResponse(
                invite.getId(), invite.getGroupId(), invite.getInviterUserId(),
                invite.getInviteeUserId(), invite.getStatus().name(),
                invite.getCreatedAt(), invite.getActedAt()
        );
    }

    // ─── Group Invites ─────────────────────────────────────────────────────────

    @PostMapping("/groups/{groupId}/invite")
    @ResponseStatus(HttpStatus.CREATED)
    public GroupInviteResponse inviteToGroup(
            Authentication authentication,
            @PathVariable UUID groupId,
            @Valid @RequestBody GroupInviteRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var invite = socialService.inviteFriendToGroup(groupId, currentUser.userId(), request.userId());
        return new GroupInviteResponse(
                invite.getId(), invite.getGroupId(), invite.getInviterUserId(),
                invite.getInviteeUserId(), invite.getStatus().name(),
                invite.getCreatedAt(), invite.getActedAt()
        );
    }

    @GetMapping("/groups/invites/incoming")
    public List<GroupInviteInboxResponse> incomingGroupInvites(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listIncomingGroupInvites(currentUser.userId()).stream()
                .map(invite -> new GroupInviteInboxResponse(
                        invite.inviteId(), invite.groupId(), invite.groupName(),
                        invite.inviterUserId(), invite.inviterName(), invite.createdAt()
                ))
                .toList();
    }

    @GetMapping("/groups/{groupId}/invites/pending")
    public List<OutgoingGroupInviteResponse> pendingGroupInvites(
            Authentication authentication,
            @PathVariable UUID groupId
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listPendingGroupInvites(groupId, currentUser.userId()).stream()
                .map(i -> new OutgoingGroupInviteResponse(
                        i.inviteId(), i.groupId(), i.inviteeUserId(),
                        i.inviteeName(), i.inviteePhone(), i.createdAt()
                ))
                .toList();
    }

    @PostMapping("/groups/{groupId}/invites/{inviteId}/respond")
    public GroupInviteResponse respondGroupInvite(
            Authentication authentication,
            @PathVariable UUID groupId,
            @PathVariable UUID inviteId,
            @Valid @RequestBody GroupInviteRespondRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        if (request.status() == GroupInviteStatus.PENDING) {
            throw new IllegalArgumentException("Status must be ACCEPTED or DECLINED.");
        }
        var updated = socialService.respondGroupInvite(groupId, inviteId, currentUser.userId(), request.status());
        return new GroupInviteResponse(
                updated.getId(), updated.getGroupId(), updated.getInviterUserId(),
                updated.getInviteeUserId(), updated.getStatus().name(),
                updated.getCreatedAt(), updated.getActedAt()
        );
    }

    // ─── Exception Handlers ───────────────────────────────────────────────────

    @ExceptionHandler({EntityNotFoundException.class})
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public Map<String, String> notFound(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    @ExceptionHandler({IllegalArgumentException.class, IllegalStateException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> badRequest(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private FriendRequestResponse toFriendRequestResponse(com.spark.backend.entity.FriendRequestEntity saved) {
        return new FriendRequestResponse(
                saved.getId(), saved.getFromUserId(), saved.getToUserId(),
                saved.getStatus().name(), saved.getCreatedAt(), saved.getRespondedAt()
        );
    }

    // ─── Request / Response Records ──────────────────────────────────────────

    public record SendFriendRequest(
            @NotBlank @Pattern(regexp = "^[0-9+()\\-\\s]{8,20}$") String phoneNumber,
            @Size(max = 280) String message
    ) {}

    public record FriendRequestRespondRequest(FriendRequestStatus status) {}

    public record FriendRequestResponse(
            UUID requestId, String fromUserId, String toUserId,
            String status, Instant createdAt, Instant respondedAt
    ) {}

    public record FriendSummaryResponse(
            String userId, String displayName, String phoneNumber, String availabilityStatus
    ) {}

    public record FriendIncomingRequestResponse(
            UUID requestId, String fromUserId, String displayName,
            String phoneNumber, Instant createdAt, String message
    ) {}

    public record OutgoingFriendRequestResponse(
            UUID requestId, String toUserId, String displayName,
            String phoneNumber, Instant createdAt, String message
    ) {}

    public record FriendSuggestionResponse(
            String userId, String displayName, String phoneNumber, int mutualGroupCount
    ) {}

    public record ContactMatchRequest(@NotEmpty List<String> phoneNumbers) {}

    public record MatchedContactResponse(
            String userId, String displayName, String phoneNumber, boolean alreadyFriend
    ) {}

    public record SetAvailabilityRequest(
            @NotBlank @Pattern(regexp = "NONE|OPEN") String status
    ) {}

    public record ReportUserRequest(@Size(max = 500) String reason) {}

    public record CreateGroupRequest(
            @NotBlank @Size(max = 140) String name,
            @Size(max = 280) String description
    ) {}

    public record UpdateGroupRequest(
            @NotBlank @Size(max = 140) String name,
            @Size(max = 280) String description
    ) {}

    public record GroupSummaryResponse(
            UUID groupId, String name, String description,
            String ownerUserId, String myRole, int memberCount, boolean archived
    ) {}

    public record GroupMemberResponse(
            String userId, String displayName, String phoneNumber, String role
    ) {}

    public record GroupDetailResponse(
            UUID groupId, String name, String description,
            String ownerUserId, String myRole, List<GroupMemberResponse> members, boolean archived
    ) {}

    public record GroupInviteRequest(@NotBlank String userId) {}

    public record GroupInviteResponse(
            UUID inviteId, UUID groupId, String inviterUserId,
            String inviteeUserId, String status, Instant createdAt, Instant actedAt
    ) {}

    public record GroupInviteInboxResponse(
            UUID inviteId, UUID groupId, String groupName,
            String inviterUserId, String inviterName, Instant createdAt
    ) {}

    public record OutgoingGroupInviteResponse(
            UUID inviteId, UUID groupId, String inviteeUserId,
            String inviteeName, String inviteePhone, Instant createdAt
    ) {}

    public record GroupInviteRespondRequest(GroupInviteStatus status) {}

    public record GroupActivityResponse(
            String eventId, String type, String userId, String displayName, Instant timestamp
    ) {}
}
