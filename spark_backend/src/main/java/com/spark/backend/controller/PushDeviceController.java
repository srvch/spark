package com.spark.backend.controller;

import com.spark.backend.security.CurrentUser;
import com.spark.backend.service.DeviceTokenService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/push/devices")
public class PushDeviceController {
    private final DeviceTokenService deviceTokenService;

    public PushDeviceController(DeviceTokenService deviceTokenService) {
        this.deviceTokenService = deviceTokenService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void register(Authentication authentication, @Valid @RequestBody RegisterDeviceRequest req) {
        String userId = ((CurrentUser) authentication.getPrincipal()).userId();
        deviceTokenService.register(userId, req.token(), req.platform());
    }

    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unregister(Authentication authentication, @Valid @RequestBody UnregisterDeviceRequest req) {
        String userId = ((CurrentUser) authentication.getPrincipal()).userId();
        deviceTokenService.unregister(userId, req.token());
    }

    @ExceptionHandler({IllegalArgumentException.class, IllegalStateException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> badRequest(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    public record RegisterDeviceRequest(
            @NotBlank String token,
            @NotBlank
            @Pattern(regexp = "^(android|ios|web)$")
            String platform
    ) {
    }

    public record UnregisterDeviceRequest(@NotBlank String token) {
    }
}
