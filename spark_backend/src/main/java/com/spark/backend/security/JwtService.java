package com.spark.backend.security;

import com.spark.backend.config.SparkAuthProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.Map;

@Service
public class JwtService {
    private static final Logger log = LoggerFactory.getLogger(JwtService.class);
    private static final String DEFAULT_SECRET = "change-this-super-secret-key-change-this-super-secret-key";

    private final SparkAuthProperties authProperties;
    private final SecretKey key;

    public JwtService(SparkAuthProperties authProperties) {
        this.authProperties = authProperties;
        String secret = authProperties.jwtSecret();
        if (DEFAULT_SECRET.equals(secret)) {
            log.warn("⚠️  SECURITY: Using default JWT secret. Set SPARK_JWT_SECRET before deploying to production!");
        }
        if (secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("SPARK_JWT_SECRET must be at least 32 bytes.");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String generateToken(String userId, String phoneNumber) {
        Instant now = Instant.now();
        Instant expiry = now.plusSeconds(authProperties.jwtExpirySeconds());
        return Jwts.builder()
                .subject(userId)
                .claims(Map.of("phoneNumber", phoneNumber))
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .signWith(key)
                .compact();
    }

    public CurrentUser parse(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        String userId = claims.getSubject();
        String phone = claims.get("phoneNumber", String.class);
        return new CurrentUser(userId, phone);
    }
}
