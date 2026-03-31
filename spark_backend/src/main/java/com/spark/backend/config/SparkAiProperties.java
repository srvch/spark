package com.spark.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "spark.ai")
public record SparkAiProperties(
        boolean enabled,
        String provider,
        String model,
        String geminiApiKey,
        int timeoutMillis
) {
}
