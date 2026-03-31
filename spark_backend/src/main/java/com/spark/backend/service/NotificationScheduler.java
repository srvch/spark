package com.spark.backend.service;

import com.spark.backend.domain.SparkStatus;
import com.spark.backend.repository.SparkEventRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
public class NotificationScheduler {
    private final SparkEventRepository sparkEventRepository;
    private final NotificationService notificationService;

    public NotificationScheduler(
            SparkEventRepository sparkEventRepository,
            NotificationService notificationService
    ) {
        this.sparkEventRepository = sparkEventRepository;
        this.notificationService = notificationService;
    }

    @Scheduled(fixedDelay = 60000)
    public void processStartReminders() {
        Instant now = Instant.now();
        // 15-minute reminder window.
        Instant min15 = now.plusSeconds(14 * 60L);
        Instant max15 = now.plusSeconds(15 * 60L + 59);
        sparkEventRepository.findByStatusAndStartsAtBetween(SparkStatus.ACTIVE, min15, max15)
                .forEach(spark -> notificationService.sendStartsSoonReminder(spark, 15));

        // 60-minute reminder window.
        Instant min60 = now.plusSeconds(59 * 60L);
        Instant max60 = now.plusSeconds(60 * 60L + 59);
        sparkEventRepository.findByStatusAndStartsAtBetween(SparkStatus.ACTIVE, min60, max60)
                .forEach(spark -> notificationService.sendStartsSoonReminder(spark, 60));
    }
}
