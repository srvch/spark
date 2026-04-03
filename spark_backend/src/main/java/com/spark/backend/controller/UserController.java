package com.spark.backend.controller;

import com.spark.backend.entity.AppUserEntity;
import com.spark.backend.repository.AppUserRepository;
import com.spark.backend.security.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final AppUserRepository appUserRepository;

    public UserController(AppUserRepository appUserRepository) {
        this.appUserRepository = appUserRepository;
    }

    @GetMapping("/me")
    public ProfileResponse getProfile(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        AppUserEntity user = appUserRepository.findById(UUID.fromString(currentUser.userId()))
                .orElseThrow(() -> new jakarta.persistence.EntityNotFoundException("User not found."));
        return new ProfileResponse(
                user.getId().toString(),
                user.getDisplayName(),
                user.getPhoneNumber(),
                user.getCreatedAt()
        );
    }

    @PutMapping("/me")
    public ProfileResponse updateProfile(
            Authentication authentication,
            @Valid @RequestBody UpdateProfileRequest request
    ) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        AppUserEntity user = appUserRepository.findById(UUID.fromString(currentUser.userId()))
                .orElseThrow(() -> new jakarta.persistence.EntityNotFoundException("User not found."));
        user.setDisplayName(request.displayName().trim());
        AppUserEntity saved = appUserRepository.save(user);
        return new ProfileResponse(
                saved.getId().toString(),
                saved.getDisplayName(),
                saved.getPhoneNumber(),
                saved.getCreatedAt()
        );
    }

    @ExceptionHandler({jakarta.persistence.EntityNotFoundException.class})
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public Map<String, String> notFound(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    @ExceptionHandler({IllegalArgumentException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> badRequest(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    public record ProfileResponse(
            String userId,
            String displayName,
            String phoneNumber,
            Instant createdAt
    ) {}

    public record UpdateProfileRequest(
            @NotBlank @Size(min = 2, max = 120) String displayName
    ) {}
}
