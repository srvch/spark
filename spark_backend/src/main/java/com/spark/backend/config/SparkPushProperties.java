package com.spark.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "spark.push")
public record SparkPushProperties(
        boolean enabled,
        String credentialsPath
) {
}
