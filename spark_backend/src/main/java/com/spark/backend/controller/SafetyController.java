package com.spark.backend.controller;

import com.spark.backend.security.CurrentUser;
import com.spark.backend.service.SafetyService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/safety")
public class SafetyController {
    private final SafetyService safetyService;

    public SafetyController(SafetyService safetyService) {
        this.safetyService = safetyService;
    }

    @GetMapping("/guidelines")
    public GuidelinesResponse guidelines() {
        return new GuidelinesResponse(safetyService.guidelines());
    }

    @PostMapping("/sos")
    @ResponseStatus(HttpStatus.CREATED)
    public SosResponse triggerSos(
            Authentication authentication,
            @Valid @RequestBody SosRequest request
    ) {
        String userId = ((CurrentUser) authentication.getPrincipal()).userId();
        var alert = safetyService.createAlert(
                new SafetyService.CreateSafetyAlertCommand(
                        userId,
                        request.sparkId(),
                        request.locationName(),
                        request.note()
                )
        );
        return new SosResponse(alert.getId(), alert.getStatus(), alert.getCreatedAt());
    }

    @ExceptionHandler({IllegalArgumentException.class, IllegalStateException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> badRequest(Exception ex) {
        return Map.of("error", ex.getMessage());
    }

    public record GuidelinesResponse(List<String> guidelines) {
    }

    public record SosRequest(
            UUID sparkId, // Can be null for global safety reports
            @NotBlank @Size(max = 180) String locationName,
            @Size(max = 500) String note
    ) {
    }

    public record SosResponse(UUID alertId, String status, Instant createdAt) {
    }
}
