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

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
