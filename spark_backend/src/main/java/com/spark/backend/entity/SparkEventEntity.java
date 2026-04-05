package com.spark.backend.entity;

import com.spark.backend.domain.SparkStatus;
import com.spark.backend.domain.SparkVisibility;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "spark_events")
public class SparkEventEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "host_user_id", nullable = false, length = 128)
    private String hostUserId;

    @Column(nullable = false, length = 32)
    private String category;

    @Column(nullable = false, length = 180)
    private String title;

    @Column(length = 300)
    private String note;

    @Column(name = "location_name", nullable = false, length = 180)
    private String locationName;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    @Column(name = "starts_at", nullable = false)
    private Instant startsAt;

    @Column(name = "ends_at")
    private Instant endsAt;

    @Column(name = "max_spots", nullable = false)
    private int maxSpots;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private SparkVisibility visibility = SparkVisibility.PUBLIC;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private SparkStatus status = SparkStatus.ACTIVE;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** NULL = one-off spark; DAILY / WEEKLY = this spark is a recurring template */
    @Column(name = "recurrence_type", length = 16)
    private String recurrenceType;

    /** For WEEKLY recurrence: 1=Monday … 7=Sunday */
    @Column(name = "recurrence_day_of_week")
    private Integer recurrenceDayOfWeek;

    /** HH:mm string, e.g. "18:30" */
    @Column(name = "recurrence_time", length = 8)
    private String recurrenceTime;

    @Column(name = "recurrence_end_date")
    private java.time.LocalDate recurrenceEndDate;

    /** UUID of the template spark that spawned this instance */
    @Column(name = "template_id")
    private UUID templateId;

    /** Last time this template spawned a new spark instance */
    @Column(name = "last_spawned_at")
    private Instant lastSpawnedAt;

    /** Pre-computed next spawn time (set by the scheduler) */
    @Column(name = "next_occurs_at")
    private Instant nextOccursAt;

    @PrePersist
    void onCreate() {
        createdAt = Instant.now();
        updatedAt = createdAt;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public String getHostUserId() {
        return hostUserId;
    }

    public void setHostUserId(String hostUserId) {
        this.hostUserId = hostUserId;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public String getLocationName() {
        return locationName;
    }

    public void setLocationName(String locationName) {
        this.locationName = locationName;
    }

    public double getLatitude() {
        return latitude;
    }

    public void setLatitude(double latitude) {
        this.latitude = latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public void setLongitude(double longitude) {
        this.longitude = longitude;
    }

    public Instant getStartsAt() {
        return startsAt;
    }

    public void setStartsAt(Instant startsAt) {
        this.startsAt = startsAt;
    }

    public Instant getEndsAt() {
        return endsAt;
    }

    public void setEndsAt(Instant endsAt) {
        this.endsAt = endsAt;
    }

    public int getMaxSpots() {
        return maxSpots;
    }

    public void setMaxSpots(int maxSpots) {
        this.maxSpots = maxSpots;
    }

    public SparkStatus getStatus() {
        return status;
    }

    public void setStatus(SparkStatus status) {
        this.status = status;
    }

    public SparkVisibility getVisibility() {
        return visibility;
    }

    public void setVisibility(SparkVisibility visibility) {
        this.visibility = visibility;
    }

    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }

    public String getRecurrenceType() { return recurrenceType; }
    public void setRecurrenceType(String recurrenceType) { this.recurrenceType = recurrenceType; }

    public Integer getRecurrenceDayOfWeek() { return recurrenceDayOfWeek; }
    public void setRecurrenceDayOfWeek(Integer recurrenceDayOfWeek) { this.recurrenceDayOfWeek = recurrenceDayOfWeek; }

    public String getRecurrenceTime() { return recurrenceTime; }
    public void setRecurrenceTime(String recurrenceTime) { this.recurrenceTime = recurrenceTime; }

    public java.time.LocalDate getRecurrenceEndDate() { return recurrenceEndDate; }
    public void setRecurrenceEndDate(java.time.LocalDate recurrenceEndDate) { this.recurrenceEndDate = recurrenceEndDate; }

    public UUID getTemplateId() { return templateId; }
    public void setTemplateId(UUID templateId) { this.templateId = templateId; }

    public Instant getLastSpawnedAt() { return lastSpawnedAt; }
    public void setLastSpawnedAt(Instant lastSpawnedAt) { this.lastSpawnedAt = lastSpawnedAt; }

    public Instant getNextOccursAt() { return nextOccursAt; }
    public void setNextOccursAt(Instant nextOccursAt) { this.nextOccursAt = nextOccursAt; }
}
