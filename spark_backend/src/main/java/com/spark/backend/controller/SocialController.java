package com.spark.backend.controller;

import com.spark.backend.domain.FriendRequestStatus;
import com.spark.backend.domain.GroupInviteStatus;
import com.spark.backend.security.CurrentUser;
import com.spark.backend.service.SocialService;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
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

    @PostMapping("/friends/request")
    @ResponseStatus(HttpStatus.CREATED)
    public FriendRequestResponse sendFriendRequest(
            Authentication authentication,
            @Valid @RequestBody SendFriendRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var saved = socialService.sendFriendRequest(currentUser.userId(), request.phoneNumber());
        return new FriendRequestResponse(
                saved.getId(),
                saved.getFromUserId(),
                saved.getToUserId(),
                saved.getStatus().name(),
                saved.getCreatedAt(),
                saved.getRespondedAt()
        );
    }

    @GetMapping("/friends")
    public List<FriendSummaryResponse> friends(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listFriends(currentUser.userId()).stream()
                .map(friend -> new FriendSummaryResponse(
                        friend.userId(),
                        friend.displayName(),
                        friend.phoneNumber()
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
                        request.createdAt()
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
        return new FriendRequestResponse(
                updated.getId(),
                updated.getFromUserId(),
                updated.getToUserId(),
                updated.getStatus().name(),
                updated.getCreatedAt(),
                updated.getRespondedAt()
        );
    }

    @PostMapping("/groups")
    @ResponseStatus(HttpStatus.CREATED)
    public GroupSummaryResponse createGroup(
            Authentication authentication,
            @Valid @RequestBody CreateGroupRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var group = socialService.createGroup(currentUser.userId(), request.name(), request.description());
        return new GroupSummaryResponse(
                group.getId(),
                group.getName(),
                group.getDescription(),
                group.getOwnerUserId(),
                "OWNER",
                1
        );
    }

    @GetMapping("/groups")
    public List<GroupSummaryResponse> groups(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listGroupsForUser(currentUser.userId()).stream()
                .map(group -> new GroupSummaryResponse(
                        group.groupId(),
                        group.name(),
                        group.description(),
                        group.ownerUserId(),
                        group.myRole().name(),
                        group.memberCount()
                ))
                .toList();
    }

    @GetMapping("/groups/{groupId}")
    public GroupDetailResponse groupDetail(Authentication authentication, @PathVariable UUID groupId) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        var group = socialService.getGroupDetail(groupId, currentUser.userId());
        var members = group.members().stream()
                .map(member -> new GroupMemberResponse(
                        member.userId(),
                        member.displayName(),
                        member.phoneNumber(),
                        member.role().name()
                ))
                .toList();
        return new GroupDetailResponse(
                group.groupId(),
                group.name(),
                group.description(),
                group.ownerUserId(),
                group.myRole().name(),
                members
        );
    }

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
                invite.getId(),
                invite.getGroupId(),
                invite.getInviterUserId(),
                invite.getInviteeUserId(),
                invite.getStatus().name(),
                invite.getCreatedAt(),
                invite.getActedAt()
        );
    }

    @GetMapping("/groups/invites/incoming")
    public List<GroupInviteInboxResponse> incomingGroupInvites(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        return socialService.listIncomingGroupInvites(currentUser.userId()).stream()
                .map(invite -> new GroupInviteInboxResponse(
                        invite.inviteId(),
                        invite.groupId(),
                        invite.groupName(),
                        invite.inviterUserId(),
                        invite.inviterName(),
                        invite.createdAt()
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
                updated.getId(),
                updated.getGroupId(),
                updated.getInviterUserId(),
                updated.getInviteeUserId(),
                updated.getStatus().name(),
                updated.getCreatedAt(),
                updated.getActedAt()
        );
    }

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

    public record SendFriendRequest(
            @NotBlank
            @Pattern(regexp = "^[0-9+()\\-\\s]{8,20}$") String phoneNumber
    ) {
    }

    public record FriendRequestRespondRequest(
            FriendRequestStatus status
    ) {
    }

    public record FriendRequestResponse(
            UUID requestId,
            String fromUserId,
            String toUserId,
            String status,
            Instant createdAt,
            Instant respondedAt
    ) {
    }

    public record FriendSummaryResponse(
            String userId,
            String displayName,
            String phoneNumber
    ) {
    }

    public record FriendIncomingRequestResponse(
            UUID requestId,
            String fromUserId,
            String displayName,
            String phoneNumber,
            Instant createdAt
    ) {
    }

    public record CreateGroupRequest(
            @NotBlank @Size(max = 140) String name,
            @Size(max = 280) String description
    ) {
    }

    public record GroupSummaryResponse(
            UUID groupId,
            String name,
            String description,
            String ownerUserId,
            String myRole,
            int memberCount
    ) {
    }

    public record GroupMemberResponse(
            String userId,
            String displayName,
            String phoneNumber,
            String role
    ) {
    }

    public record GroupDetailResponse(
            UUID groupId,
            String name,
            String description,
            String ownerUserId,
            String myRole,
            List<GroupMemberResponse> members
    ) {
    }

    public record GroupInviteRequest(
            @NotBlank String userId
    ) {
    }

    public record GroupInviteResponse(
            UUID inviteId,
            UUID groupId,
            String inviterUserId,
            String inviteeUserId,
            String status,
            Instant createdAt,
            Instant actedAt
    ) {
    }

    public record GroupInviteInboxResponse(
            UUID inviteId,
            UUID groupId,
            String groupName,
            String inviterUserId,
            String inviterName,
            Instant createdAt
    ) {
    }

    public record GroupInviteRespondRequest(
            GroupInviteStatus status
    ) {
    }
}

