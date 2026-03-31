package com.spark.backend.service;

import com.spark.backend.config.SparkLiveProperties;
import org.springframework.data.geo.Circle;
import org.springframework.data.geo.Distance;
import org.springframework.data.geo.GeoResult;
import org.springframework.data.geo.GeoResults;
import org.springframework.data.geo.Metrics;
import org.springframework.data.geo.Point;
import org.springframework.data.redis.connection.RedisGeoCommands;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.*;

@Service
public class LiveSparkCacheService {
    private final StringRedisTemplate redis;
    private final SparkLiveProperties props;

    public LiveSparkCacheService(StringRedisTemplate redis, SparkLiveProperties props) {
        this.redis = redis;
        this.props = props;
    }

    public long defaultTtlSeconds() {
        return props.ttlSeconds();
    }

    public void upsert(LiveSpark spark, Duration ttl) {
        String key = key(spark.id().toString());
        Map<String, String> data = new HashMap<>();
        data.put("id", spark.id().toString());
        data.put("title", spark.title());
        data.put("category", spark.category());
        data.put("locationName", spark.locationName());
        data.put("latitude", Double.toString(spark.latitude()));
        data.put("longitude", Double.toString(spark.longitude()));
        data.put("startsAt", spark.startsAt().toString());
        data.put("maxSpots", Integer.toString(spark.maxSpots()));
        data.put("joinedCount", Integer.toString(spark.joinedCount()));
        data.put("hostUserId", spark.hostUserId());

        redis.opsForHash().putAll(key, data);
        redis.expire(key, ttl);
        redis.opsForGeo().add(props.geoKey(), new Point(spark.longitude(), spark.latitude()), spark.id().toString());
    }

    public void remove(UUID sparkId) {
        String id = sparkId.toString();
        redis.delete(key(id));
        redis.opsForGeo().remove(props.geoKey(), id);
    }

    public NearbyPage findNearby(double latitude, double longitude, double radiusKm, int page, int size) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.max(size, 1);
        int start = safePage * safeSize;
        int fetchLimit = start + safeSize + 1;

        Circle circle = new Circle(new Point(longitude, latitude), new Distance(radiusKm, Metrics.KILOMETERS));
        RedisGeoCommands.GeoRadiusCommandArgs args = RedisGeoCommands.GeoRadiusCommandArgs
                .newGeoRadiusArgs()
                .includeDistance()
                .sortAscending()
                .limit(fetchLimit);

        GeoResults<RedisGeoCommands.GeoLocation<String>> results = redis.opsForGeo().radius(props.geoKey(), circle, args);
        if (results == null || results.getContent().isEmpty()) {
            return new NearbyPage(List.of(), false);
        }

        List<NearbyLiveSpark> all = new ArrayList<>();
        for (GeoResult<RedisGeoCommands.GeoLocation<String>> result : results.getContent()) {
            String id = result.getContent().getName();
            if (id == null) continue;
            Map<Object, Object> hash = redis.opsForHash().entries(key(id));
            if (hash.isEmpty()) {
                redis.opsForGeo().remove(props.geoKey(), id);
                continue;
            }
            all.add(
                    new NearbyLiveSpark(
                            UUID.fromString(id),
                            value(hash, "title"),
                            value(hash, "category"),
                            value(hash, "locationName"),
                            parseInstant(value(hash, "startsAt")),
                            parseInt(value(hash, "maxSpots"), 0),
                            parseInt(value(hash, "joinedCount"), 0),
                            result.getDistance() == null ? 0 : result.getDistance().getValue(),
                            value(hash, "hostUserId")
                    )
            );
        }
        if (start >= all.size()) {
            return new NearbyPage(List.of(), false);
        }
        int endExclusive = Math.min(start + safeSize, all.size());
        boolean hasMore = all.size() > endExclusive;
        return new NearbyPage(all.subList(start, endExclusive), hasMore);
    }

    private String key(String sparkId) {
        return "spark:live:" + sparkId;
    }

    private String value(Map<Object, Object> map, String field) {
        Object v = map.get(field);
        return v == null ? "" : v.toString();
    }

    private int parseInt(String value, int fallback) {
        try {
            return Integer.parseInt(value);
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private Instant parseInstant(String value) {
        try {
            return Instant.parse(value);
        } catch (Exception ignored) {
            return Instant.now();
        }
    }

    public record LiveSpark(
            UUID id,
            String title,
            String category,
            String locationName,
            double latitude,
            double longitude,
            Instant startsAt,
            int maxSpots,
            int joinedCount,
            String hostUserId
    ) {
    }

    public record NearbyLiveSpark(
            UUID id,
            String title,
            String category,
            String locationName,
            Instant startsAt,
            int maxSpots,
            int joinedCount,
            double distanceKm,
            String hostUserId
    ) {
    }

    public record NearbyPage(
            List<NearbyLiveSpark> items,
            boolean hasMore
    ) {
    }
}
