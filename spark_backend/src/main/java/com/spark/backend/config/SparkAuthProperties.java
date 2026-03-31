package com.spark.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "spark.auth")
public record SparkAuthProperties(
        String jwtSecret,
        long jwtExpirySeconds,
        long otpTtlSeconds,
        boolean exposeDebugOtp,
        boolean enableDevGuestLogin
) {
}
