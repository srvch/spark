package com.spark.backend.controller;

import com.spark.backend.service.AccountDeletionService;
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
    private final AccountDeletionService accountDeletionService;

    public UserController(AppUserRepository appUserRepository, AccountDeletionService accountDeletionService) {
        this.appUserRepository = appUserRepository;
        this.accountDeletionService = accountDeletionService;
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
                user.getCreatedAt(),
                user.getAgeBand(),
                user.getGender()
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
        user.setAgeBand(normalizeAgeBand(request.ageBand()));
        user.setGender(normalizeGender(request.gender()));
        AppUserEntity saved = appUserRepository.save(user);
        return new ProfileResponse(
                saved.getId().toString(),
                saved.getDisplayName(),
                saved.getPhoneNumber(),
                saved.getCreatedAt(),
                saved.getAgeBand(),
                saved.getGender()
        );
    }

    @DeleteMapping("/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAccount(Authentication authentication) {
        CurrentUser currentUser = (CurrentUser) authentication.getPrincipal();
        accountDeletionService.deleteAccount(currentUser.userId());
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
            Instant createdAt,
            String ageBand,
            String gender
    ) {}

    public record UpdateProfileRequest(
            @NotBlank @Size(min = 2, max = 120) String displayName,
            @NotBlank String ageBand,
            @NotBlank String gender
    ) {}

    private String normalizeAgeBand(String ageBand) {
        final String value = ageBand.trim().toUpperCase();
        if ("18-24".equals(value) ||
                "25-34".equals(value) ||
                "35-44".equals(value) ||
                "45+".equals(value)) {
            return value;
        }
        throw new IllegalArgumentException("Invalid age band.");
    }

    private String normalizeGender(String gender) {
        final String value = gender.trim().toUpperCase();
        if ("MALE".equals(value) ||
                "FEMALE".equals(value) ||
                "OTHER".equals(value)) {
            return value;
        }
        throw new IllegalArgumentException("Invalid gender.");
    }
}
