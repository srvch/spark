package com.spark.backend.service;

import com.spark.backend.domain.NotificationType;
import com.spark.backend.entity.UserNotificationEntity;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;

@Component
@ConditionalOnProperty(
        prefix = "spark.push",
        name = "enabled",
        havingValue = "false",
        matchIfMissing = true
)
public class NoopPushProvider implements PushProvider {
    @Override
    public void sendToUsers(
            List<String> recipientUserIds,
            NotificationType type,
            UUID sparkId,
            UserNotificationEntity notification
    ) {
        // No-op when FCM is not configured.
    }
}
