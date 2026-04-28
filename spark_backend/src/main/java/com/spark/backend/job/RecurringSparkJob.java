package com.spark.backend.job;

import com.spark.backend.domain.SparkStatus;
import com.spark.backend.entity.SparkEventEntity;
import com.spark.backend.repository.SparkEventRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.List;

/**
 * Runs every hour. For each active recurring spark template whose nextOccursAt
 * is due within the next 2 hours, creates a new spark instance.
 */
@Component
public class RecurringSparkJob {

    private static final Logger log = LoggerFactory.getLogger(RecurringSparkJob.class);
    /** Spawn sparks up to 2 hours before they're scheduled to start */
    private static final Duration SPAWN_HORIZON = Duration.ofHours(2);

    private final SparkEventRepository sparkEventRepository;
    private final ZoneId recurrenceZone;

    public RecurringSparkJob(SparkEventRepository sparkEventRepository,
                             @Value("${spark.recurrence.zone:Asia/Kolkata}") String recurrenceZoneId) {
        this.sparkEventRepository = sparkEventRepository;
        this.recurrenceZone = parseZone(recurrenceZoneId);
    }

    @Scheduled(fixedDelay = 3_600_000L, initialDelay = 30_000L)
    public void spawnDueSparks() {
        Instant now = Instant.now();
        Instant horizon = now.plus(SPAWN_HORIZON);

        List<SparkEventEntity> templates = sparkEventRepository.findDueRecurringTemplates(
                horizon, now);

        if (templates.isEmpty()) return;

        log.info("[RecurringJob] Processing {} recurring template(s)", templates.size());

        for (SparkEventEntity template : templates) {
            try {
                spawnNextInstance(template, now);
            } catch (Exception e) {
                log.error("[RecurringJob] Failed to spawn from template {}: {}",
                        template.getId(), e.getMessage());
            }
        }
    }

    @Transactional
    protected void spawnNextInstance(SparkEventEntity template, Instant now) {
        Instant nextStart = template.getNextOccursAt();
        if (nextStart == null) {
            nextStart = computeNextStart(template, now);
        }
        if (nextStart == null) {
            log.debug("[RecurringJob] No next occurrence for template {}", template.getId());
            // Deactivate template if its end date has passed
            template.setStatus(SparkStatus.CANCELLED);
            sparkEventRepository.save(template);
            return;
        }

        // Create the new spark instance (copy of template, different startsAt)
        SparkEventEntity instance = new SparkEventEntity();
        instance.setHostUserId(template.getHostUserId());
        instance.setCategory(template.getCategory());
        instance.setTitle(template.getTitle());
        instance.setNote(template.getNote());
        instance.setLocationName(template.getLocationName());
        instance.setLatitude(template.getLatitude());
        instance.setLongitude(template.getLongitude());
        instance.setStartsAt(nextStart);
        instance.setMaxSpots(template.getMaxSpots());
        instance.setVisibility(template.getVisibility());
        instance.setStatus(SparkStatus.ACTIVE);
        instance.setTemplateId(template.getId());

        SparkEventEntity saved = sparkEventRepository.save(instance);
        log.info("[RecurringJob] Spawned spark '{}' (id={}) from template {} for {}",
                saved.getTitle(), saved.getId(), template.getId(), nextStart);

        // Update template's tracking fields
        template.setLastSpawnedAt(now);
        template.setNextOccursAt(computeNextStart(template, nextStart));
        sparkEventRepository.save(template);
    }

    /**
     * Computes the next start time after 'after' for a recurring template.
     * Returns null if recurrenceEndDate has passed.
     */
    Instant computeNextStart(SparkEventEntity template, Instant after) {
        if (template.getRecurrenceType() == null) return null;

        // Parse recurrenceTime (HH:mm) — default 09:00
        int hour = 9;
        int minute = 0;
        if (template.getRecurrenceTime() != null) {
            try {
                String[] parts = template.getRecurrenceTime().split(":");
                if (parts.length == 2) {
                    hour = Integer.parseInt(parts[0]);
                    minute = Integer.parseInt(parts[1]);
                }
            } catch (Exception ignored) {
                hour = 9;
                minute = 0;
            }
        }

        ZonedDateTime candidate;
        ZonedDateTime base = after.atZone(recurrenceZone);

        if ("DAILY".equalsIgnoreCase(template.getRecurrenceType())) {
            candidate = base.toLocalDate().plusDays(1)
                    .atTime(hour, minute)
                    .atZone(recurrenceZone);
        } else { // WEEKLY
            int targetDay = template.getRecurrenceDayOfWeek() != null
                    ? template.getRecurrenceDayOfWeek() : 1; // default Monday
            candidate = base.toLocalDate()
                    .with(java.time.temporal.TemporalAdjusters.next(
                            java.time.DayOfWeek.of(targetDay)))
                    .atTime(hour, minute)
                    .atZone(recurrenceZone);
        }

        Instant result = candidate.toInstant();

        // Check against recurrenceEndDate
        if (template.getRecurrenceEndDate() != null) {
            LocalDate occurrenceDate = result.atZone(recurrenceZone).toLocalDate();
            if (occurrenceDate.isAfter(template.getRecurrenceEndDate())) return null;
        }

        return result;
    }

    private ZoneId parseZone(String zoneId) {
        try {
            return ZoneId.of(zoneId);
        } catch (Exception ex) {
            log.warn("[RecurringJob] Invalid recurrence zone '{}', defaulting to UTC", zoneId);
            return ZoneOffset.UTC;
        }
    }
}
