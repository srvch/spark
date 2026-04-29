package com.spark.backend.controller;

import com.spark.backend.service.PhoneAuthService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final PhoneAuthService phoneAuthService;

    public AuthController(PhoneAuthService phoneAuthService) {
        this.phoneAuthService = phoneAuthService;
    }

    @PostMapping("/firebase/verify")
    @ResponseStatus(HttpStatus.OK)
    public AuthResponse verifyFirebaseToken(@Valid @RequestBody FirebaseVerifyBody req) {
        var auth = phoneAuthService.verifyFirebaseToken(
                req.idToken(),
                req.displayName()
        );
        return new AuthResponse(
                auth.token(),
                auth.userId(),
                auth.phoneNumber(),
                auth.displayName(),
                auth.handle(),
                auth.ageBand(),
                auth.gender()
        );
    }

    @PostMapping("/otp/request")
    @ResponseStatus(HttpStatus.OK)
    public OtpRequestResponse requestOtp(@Valid @RequestBody OtpRequestBody req) {
        var requested = phoneAuthService.requestOtp(req.phoneNumber());
        return new OtpRequestResponse(
                requested.requestId(),
                requested.expiresInSeconds(),
                requested.debugOtp()
        );
    }

    @PostMapping("/otp/verify")
    @ResponseStatus(HttpStatus.OK)
    public AuthResponse verifyOtp(@Valid @RequestBody OtpVerifyBody req) {
        var auth = phoneAuthService.verifyOtp(
                req.requestId(),
                req.phoneNumber(),
                req.otp(),
                req.displayName()
        );
        return new AuthResponse(
                auth.token(),
                auth.userId(),
                auth.phoneNumber(),
                auth.displayName(),
                auth.handle(),
                auth.ageBand(),
                auth.gender()
        );
    }

    @PostMapping("/dev/guest")
    @ResponseStatus(HttpStatus.OK)
    public AuthResponse loginAsGuest() {
        var auth = phoneAuthService.loginAsGuest();
        return new AuthResponse(
                auth.token(),
                auth.userId(),
                auth.phoneNumber(),
                auth.displayName(),
                auth.handle(),
                auth.ageBand(),
                auth.gender()
        );
    }

    public record OtpRequestBody(
            @NotBlank @Pattern(regexp = "^[0-9+()\\-\\s]{8,20}$") String phoneNumber
    ) {
    }

    public record OtpVerifyBody(
            @NotBlank String requestId,
            @NotBlank @Pattern(regexp = "^[0-9+()\\-\\s]{8,20}$") String phoneNumber,
            @NotBlank @Pattern(regexp = "^[0-9]{6}$") String otp,
            @Size(max = 120) String displayName
    ) {
    }

    public record FirebaseVerifyBody(
            @NotBlank String idToken,
            @Size(max = 120) String displayName
    ) {
    }

    public record OtpRequestResponse(
            String requestId,
            long expiresInSeconds,
            String debugOtp
    ) {
    }

    public record AuthResponse(
            String token,
            String userId,
            String phoneNumber,
            String displayName,
            String handle,
            String ageBand,
            String gender
    ) {
    }

    @ExceptionHandler({IllegalArgumentException.class, IllegalStateException.class})
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, String> badRequest(Exception ex) {
        return Map.of("error", ex.getMessage());
    }
}
