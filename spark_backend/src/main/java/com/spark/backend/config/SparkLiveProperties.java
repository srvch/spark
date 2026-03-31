package com.spark.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "spark.live")
public record SparkLiveProperties(
        long ttlSeconds,
        String geoKey
) {
}
