package com.spark.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

/**
 * Caches each user's last known geographic position in Redis so the
 * NearbyAlertJob can send proactive "spark nearby" notifications.
 */
@Service
public class UserLocationService {

    private static final Logger log = LoggerFactory.getLogger(UserLocationService.class);
    private static final String GEO_KEY = "geo:users";
    private static final String ACTIVE_KEY = "users:active";
    private static final Duration LOCATION_TTL = Duration.ofHours(24);

    private final StringRedisTemplate redis;

    public UserLocationService(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /**
     * Records the user's most recent location in:
     * 1. A Redis GEO set for distance-based queries.
     * 2. A Redis sorted set (score = epoch seconds) so we can list recently active users.
     */
    public void updateLocation(String userId, double lat, double lng) {
        try {
            redis.opsForGeo().add(GEO_KEY,
                    new org.springframework.data.geo.Point(lng, lat), userId);

            redis.opsForZSet().add(ACTIVE_KEY, userId,
                    (double) Instant.now().getEpochSecond());
        } catch (Exception e) {
            log.debug("[UserLocation] Failed to update location for {}: {}", userId, e.getMessage());
        }
    }

    /**
     * Returns all userIds active within the last 24 hours.
     */
    public java.util.Set<String> getRecentlyActiveUserIds() {
        double cutoff = (double) Instant.now().minus(LOCATION_TTL).getEpochSecond();
        var result = redis.opsForZSet().rangeByScore(ACTIVE_KEY, cutoff, Double.MAX_VALUE);
        return result == null ? java.util.Collections.emptySet() : result;
    }

    /**
     * Returns users near the given coordinates within radiusKm, using the GEO set.
     */
    public java.util.List<String> getUsersNear(double lat, double lng, double radiusKm) {
        try {
            var results = redis.opsForGeo().radius(
                    GEO_KEY,
                    new org.springframework.data.geo.Circle(
                            new org.springframework.data.geo.Point(lng, lat),
                            new org.springframework.data.geo.Distance(
                                    radiusKm,
                                    org.springframework.data.geo.Metrics.KILOMETERS)
                    )
            );
            if (results == null) return java.util.Collections.emptyList();
            return results.getContent().stream()
                    .map(r -> r.getContent().getName())
                    .toList();
        } catch (Exception e) {
            log.debug("[UserLocation] GEO radius query failed: {}", e.getMessage());
            return java.util.Collections.emptyList();
        }
    }

    /** Marks that this user has been notified about the given spark (dedup). */
    public void markAlertSent(String sparkId, String userId) {
        String key = "alert:sent:" + sparkId;
        redis.opsForSet().add(key, userId);
        redis.expire(key, Duration.ofMinutes(30));
    }

    /** Returns true if the user has already been alerted about this spark. */
    public boolean wasAlertSent(String sparkId, String userId) {
        Boolean member = redis.opsForSet().isMember("alert:sent:" + sparkId, userId);
        return Boolean.TRUE.equals(member);
    }
}
