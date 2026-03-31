package com.spark.backend.security;

public record CurrentUser(
        String userId,
        String phoneNumber
) {
}
