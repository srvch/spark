package com.spark.backend.service;

import com.spark.backend.domain.NotificationType;
import com.spark.backend.entity.UserNotificationEntity;

import java.util.List;
import java.util.UUID;

public interface PushProvider {
    void sendToUsers(
            List<String> recipientUserIds,
            NotificationType type,
            UUID sparkId,
            UserNotificationEntity notification
    );
}
