package com.spark.backend.controller;

import com.spark.backend.service.PlanParsingService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/ai")
public class PlanAiController {
    private final PlanParsingService planParsingService;

    public PlanAiController(PlanParsingService planParsingService) {
        this.planParsingService = planParsingService;
    }

    @PostMapping("/parse-plan")
    @ResponseStatus(HttpStatus.OK)
    public ParsePlanResponse parse(Authentication authentication, @Valid @RequestBody ParsePlanRequest req) {
        var parsed = planParsingService.parsePlan(req.input(), req.locationHint());
        return new ParsePlanResponse(
                parsed.title(),
                parsed.category(),
                parsed.locationName(),
                parsed.startsAt(),
                parsed.maxSpots(),
                parsed.confidence(),
                parsed.source()
        );
    }

    public record ParsePlanRequest(
            @NotBlank @Size(max = 240) String input,
            @Size(max = 120) String locationHint
    ) {
    }

    public record ParsePlanResponse(
            String title,
            String category,
            String locationName,
            Instant startsAt,
            int maxSpots,
            double confidence,
            String source
    ) {
    }

    @ExceptionHandler(IllegalArgumentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> badRequest(Exception ex) {
        return Map.of("error", ex.getMessage());
    }
}
