package com.spark.backend.job;

import com.spark.backend.domain.SparkStatus;
import com.spark.backend.entity.SparkEventEntity;
import com.spark.backend.repository.SparkEventRepository;
import com.spark.backend.service.NotificationService;
import com.spark.backend.service.UserLocationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Runs every 15 minutes. For each spark created in the last 15 minutes,
 * finds nearby users and sends a proactive push notification.
 */
@Component
public class NearbyAlertJob {

    private static final Logger log = LoggerFactory.getLogger(NearbyAlertJob.class);
    private static final double ALERT_RADIUS_KM = 5.0;
    private static final int INTERVAL_MINUTES = 15;

    private final SparkEventRepository sparkEventRepository;
    private final UserLocationService userLocationService;
    private final NotificationService notificationService;

    public NearbyAlertJob(SparkEventRepository sparkEventRepository,
                          UserLocationService userLocationService,
                          NotificationService notificationService) {
        this.sparkEventRepository = sparkEventRepository;
        this.userLocationService = userLocationService;
        this.notificationService = notificationService;
    }

    @Scheduled(fixedDelay = INTERVAL_MINUTES * 60_000L, initialDelay = 60_000L)
    public void sendNearbyAlerts() {
        Instant since = Instant.now().minus(INTERVAL_MINUTES, ChronoUnit.MINUTES);
        List<SparkEventEntity> newSparks =
                sparkEventRepository.findByCreatedAtAfterAndStatus(since, SparkStatus.ACTIVE);

        if (newSparks.isEmpty()) return;

        log.info("[NearbyAlert] Checking {} new spark(s) for nearby user alerts", newSparks.size());

        for (SparkEventEntity spark : newSparks) {
            String sparkId = spark.getId().toString();
            List<String> nearbyUsers = userLocationService.getUsersNear(
                    spark.getLatitude(), spark.getLongitude(), ALERT_RADIUS_KM);

            int sent = 0;
            for (String userId : nearbyUsers) {
                // Skip the host
                if (userId.equals(spark.getHostUserId())) continue;
                // Dedup — don't send the same alert twice
                if (userLocationService.wasAlertSent(sparkId, userId)) continue;

                try {
                    notificationService.sendNearbySparkAlert(userId, spark);
                    userLocationService.markAlertSent(sparkId, userId);
                    sent++;
                } catch (Exception e) {
                    log.warn("[NearbyAlert] Failed to notify user {}: {}", userId, e.getMessage());
                }
            }

            if (sent > 0) {
                log.info("[NearbyAlert] Sent alerts for spark '{}' to {} user(s)", spark.getTitle(), sent);
            }
        }
    }
}
