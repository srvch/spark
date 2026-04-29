package com.spark.backend.service;

import com.google.firebase.FirebaseApp;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import com.spark.backend.config.SparkAuthProperties;
import com.spark.backend.entity.AppUserEntity;
import com.spark.backend.repository.AppUserRepository;
import com.spark.backend.security.JwtService;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class PhoneAuthService {
    private static final int OTP_RATE_LIMIT_MAX = 5;
    private static final int OTP_RATE_LIMIT_WINDOW_SECONDS = 3600;

    private final StringRedisTemplate redisTemplate;
    private final SparkAuthProperties authProperties;
    private final AppUserRepository appUserRepository;
    private final JwtService jwtService;

    public PhoneAuthService(
            StringRedisTemplate redisTemplate,
            SparkAuthProperties authProperties,
            AppUserRepository appUserRepository,
            JwtService jwtService
    ) {
        this.redisTemplate = redisTemplate;
        this.authProperties = authProperties;
        this.appUserRepository = appUserRepository;
        this.jwtService = jwtService;
    }

    public OtpRequested requestOtp(String phoneNumber) {
        String normalized = normalizePhone(phoneNumber);
        enforceOtpRateLimit(normalized);
        String requestId = UUID.randomUUID().toString();
        String otp = String.valueOf(ThreadLocalRandom.current().nextInt(100000, 999999));
        String payload = normalized + "|" + otp;
        redisTemplate.opsForValue().set(
                key(requestId),
                payload,
                Duration.ofSeconds(authProperties.otpTtlSeconds())
        );
        return new OtpRequested(
                requestId,
                authProperties.otpTtlSeconds(),
                authProperties.exposeDebugOtp() ? otp : null
        );
    }

    public AuthenticatedSession verifyFirebaseToken(String idToken, String displayName) {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                throw new IllegalStateException(
                        "Firebase Admin is not initialized on backend. Set SPARK_FIREBASE_CONFIG_PATH or SPARK_FIREBASE_CREDENTIALS_JSON."
                );
            }
            FirebaseAuth firebaseAuth = firebaseAuth();
            FirebaseToken decodedToken = firebaseAuth.verifyIdToken(idToken);
            String phoneNumber = decodedToken.getClaims().get("phone_number") != null 
                    ? (String) decodedToken.getClaims().get("phone_number")
                    : firebaseAuth.getUser(decodedToken.getUid()).getPhoneNumber();
            
            if (phoneNumber == null || phoneNumber.isEmpty()) {
                throw new IllegalArgumentException("No phone number found in Firebase token.");
            }

            String normalized = normalizePhone(phoneNumber);
            AppUserEntity user = appUserRepository.findByPhoneNumber(normalized).orElseGet(() -> {
                AppUserEntity entity = new AppUserEntity();
                entity.setPhoneNumber(normalized);
                entity.setDisplayName((displayName == null || displayName.isBlank())
                        ? "Spark user"
                        : displayName.trim());
                return appUserRepository.save(entity);
            });

            if (displayName != null && !displayName.isBlank() && !displayName.trim().equals(user.getDisplayName())) {
                user.setDisplayName(displayName.trim());
                user = appUserRepository.save(user);
            }

            String token = jwtService.generateToken(user.getId().toString(), user.getPhoneNumber());
            return new AuthenticatedSession(
                    token,
                    user.getId().toString(),
                    user.getPhoneNumber(),
                    user.getDisplayName(),
                    user.getHandle(),
                    user.getAgeBand(),
                    user.getGender()
            );

        } catch (FirebaseAuthException e) {
            throw new IllegalArgumentException("Invalid Firebase token: " + e.getMessage());
        }
    }

    private FirebaseAuth firebaseAuth() {
        for (FirebaseApp app : FirebaseApp.getApps()) {
            if (FirebaseApp.DEFAULT_APP_NAME.equals(app.getName())) {
                return FirebaseAuth.getInstance(app);
            }
        }
        return FirebaseAuth.getInstance(FirebaseApp.getApps().get(0));
    }

    public AuthenticatedSession verifyOtp(
            String requestId,
            String phoneNumber,
            String otp,
            String displayName
    ) {
        String normalized = normalizePhone(phoneNumber);
        String key = key(requestId);
        String payload = redisTemplate.opsForValue().get(key);
        if (payload == null) {
            throw new IllegalArgumentException("OTP expired. Request again.");
        }
        String[] split = payload.split("\\|");
        if (split.length != 2) {
            throw new IllegalArgumentException("Invalid OTP session.");
        }
        if (!split[0].equals(normalized) || !split[1].equals(otp)) {
            throw new IllegalArgumentException("Invalid OTP.");
        }
        redisTemplate.delete(key);

        AppUserEntity user = appUserRepository.findByPhoneNumber(normalized).orElseGet(() -> {
            AppUserEntity entity = new AppUserEntity();
            entity.setPhoneNumber(normalized);
            entity.setDisplayName((displayName == null || displayName.isBlank())
                    ? "Spark user"
                    : displayName.trim());
            return appUserRepository.save(entity);
        });
        if (displayName != null && !displayName.isBlank() && !displayName.trim().equals(user.getDisplayName())) {
            user.setDisplayName(displayName.trim());
            user = appUserRepository.save(user);
        }

        String token = jwtService.generateToken(user.getId().toString(), user.getPhoneNumber());
        return new AuthenticatedSession(
                token,
                user.getId().toString(),
                user.getPhoneNumber(),
                user.getDisplayName(),
                user.getHandle(),
                user.getAgeBand(),
                user.getGender()
        );
    }

    private String key(String requestId) {
        return "auth:otp:" + requestId;
    }

    private void enforceOtpRateLimit(String normalizedPhone) {
        String key = "auth:ratelimit:otp:" + normalizedPhone;
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1) {
            redisTemplate.expire(key, Duration.ofSeconds(OTP_RATE_LIMIT_WINDOW_SECONDS));
        }
        if (count != null && count > OTP_RATE_LIMIT_MAX) {
            throw new IllegalStateException("Too many OTP requests. Please try again later.");
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

    public record OtpRequested(
            String requestId,
            long expiresInSeconds,
            String debugOtp
    ) {
    }

    public record AuthenticatedSession(
            String token,
            String userId,
            String phoneNumber,
            String displayName,
            String handle,
            String ageBand,
            String gender
    ) {
    }

    public AuthenticatedSession loginAsGuest() {
        if (!authProperties.enableDevGuestLogin()) {
            throw new IllegalStateException("Guest login is disabled.");
        }

        final String guestPhone = "+910000000000";
        AppUserEntity user = appUserRepository.findByPhoneNumber(guestPhone).orElseGet(() -> {
            AppUserEntity entity = new AppUserEntity();
            entity.setPhoneNumber(guestPhone);
            entity.setDisplayName("Guest user");
            return appUserRepository.save(entity);
        });

        String token = jwtService.generateToken(user.getId().toString(), user.getPhoneNumber());
        return new AuthenticatedSession(
                token,
                user.getId().toString(),
                user.getPhoneNumber(),
                user.getDisplayName(),
                user.getHandle(),
                user.getAgeBand(),
                user.getGender()
        );
    }
}
