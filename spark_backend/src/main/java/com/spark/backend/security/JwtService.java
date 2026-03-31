package com.spark.backend.security;

import com.spark.backend.config.SparkAuthProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.Map;

@Service
public class JwtService {
    private final SparkAuthProperties authProperties;
    private final SecretKey key;

    public JwtService(SparkAuthProperties authProperties) {
        this.authProperties = authProperties;
        this.key = Keys.hmacShaKeyFor(authProperties.jwtSecret().getBytes(StandardCharsets.UTF_8));
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
