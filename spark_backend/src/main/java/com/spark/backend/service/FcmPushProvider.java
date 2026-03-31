package com.spark.backend.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.spark.backend.config.SparkPushProperties;
import com.spark.backend.domain.NotificationType;
import com.spark.backend.entity.UserNotificationEntity;
import com.spark.backend.repository.UserDeviceTokenRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.List;
import java.util.UUID;

@Component
@ConditionalOnProperty(prefix = "spark.push", name = "enabled", havingValue = "true")
public class FcmPushProvider implements PushProvider {
    private final UserDeviceTokenRepository userDeviceTokenRepository;
    private final FirebaseApp firebaseApp;

    public FcmPushProvider(
            UserDeviceTokenRepository userDeviceTokenRepository,
            SparkPushProperties pushProperties
    ) throws IOException {
        this.userDeviceTokenRepository = userDeviceTokenRepository;
        this.firebaseApp = initFirebase(pushProperties);
    }

    @Override
    public void sendToUsers(
            List<String> recipientUserIds,
            NotificationType type,
            UUID sparkId,
            UserNotificationEntity notificationEntity
    ) {
        if (recipientUserIds.isEmpty()) {
            return;
        }
        final List<String> tokens = userDeviceTokenRepository.findByUserIdInAndActiveTrue(recipientUserIds)
                .stream()
                .map(token -> token.getToken())
                .distinct()
                .toList();
        if (tokens.isEmpty()) {
            return;
        }

        final MulticastMessage message = MulticastMessage.builder()
                .addAllTokens(tokens)
                .setNotification(
                        Notification.builder()
                                .setTitle(notificationEntity.getTitle())
                                .setBody(notificationEntity.getBody())
                                .build()
                )
                .putData("notificationId", notificationEntity.getId().toString())
                .putData("type", type.name())
                .putData("sparkId", sparkId == null ? "" : sparkId.toString())
                .build();

        try {
            FirebaseMessaging.getInstance(firebaseApp).sendEachForMulticast(message);
        } catch (Exception ignored) {
            // We intentionally do not fail business flow on push errors.
        }
    }

    private FirebaseApp initFirebase(SparkPushProperties pushProperties) throws IOException {
        if (pushProperties.credentialsPath() == null || pushProperties.credentialsPath().isBlank()) {
            throw new IllegalStateException("SPARK_PUSH_CREDENTIALS_PATH is required when push is enabled.");
        }
        for (FirebaseApp app : FirebaseApp.getApps()) {
            if ("spark".equals(app.getName())) {
                return app;
            }
        }
        try (FileInputStream serviceAccount = new FileInputStream(pushProperties.credentialsPath())) {
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();
            return FirebaseApp.initializeApp(options, "spark");
        }
    }
}
