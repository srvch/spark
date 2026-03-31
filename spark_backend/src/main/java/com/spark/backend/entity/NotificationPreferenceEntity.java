package com.spark.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "notification_preferences")
public class NotificationPreferenceEntity {
    @Id
    @Column(name = "user_id", nullable = false, length = 128)
    private String userId;

    @Column(name = "notify_join", nullable = false)
    private boolean notifyJoin = true;

    @Column(name = "notify_leave_host", nullable = false)
    private boolean notifyLeaveHost = true;

    @Column(name = "notify_filling_fast", nullable = false)
    private boolean notifyFillingFast = true;

    @Column(name = "notify_starts_15", nullable = false)
    private boolean notifyStarts15 = true;

    @Column(name = "notify_starts_60", nullable = false)
    private boolean notifyStarts60 = false;

    @Column(name = "notify_new_nearby", nullable = false)
    private boolean notifyNewNearby = true;

    @Column(name = "interest_categories", nullable = false, length = 180)
    private String interestCategories = "sports,study,ride,events";

    @Column(name = "radius_km", nullable = false)
    private int radiusKm = 5;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    @PreUpdate
    void touch() {
        updatedAt = Instant.now();
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public boolean isNotifyJoin() {
        return notifyJoin;
    }

    public void setNotifyJoin(boolean notifyJoin) {
        this.notifyJoin = notifyJoin;
    }

    public boolean isNotifyLeaveHost() {
        return notifyLeaveHost;
    }

    public void setNotifyLeaveHost(boolean notifyLeaveHost) {
        this.notifyLeaveHost = notifyLeaveHost;
    }

    public boolean isNotifyFillingFast() {
        return notifyFillingFast;
    }

    public void setNotifyFillingFast(boolean notifyFillingFast) {
        this.notifyFillingFast = notifyFillingFast;
    }

    public boolean isNotifyStarts15() {
        return notifyStarts15;
    }

    public void setNotifyStarts15(boolean notifyStarts15) {
        this.notifyStarts15 = notifyStarts15;
    }

    public boolean isNotifyStarts60() {
        return notifyStarts60;
    }

    public void setNotifyStarts60(boolean notifyStarts60) {
        this.notifyStarts60 = notifyStarts60;
    }

    public boolean isNotifyNewNearby() {
        return notifyNewNearby;
    }

    public void setNotifyNewNearby(boolean notifyNewNearby) {
        this.notifyNewNearby = notifyNewNearby;
    }

    public String getInterestCategories() {
        return interestCategories;
    }

    public void setInterestCategories(String interestCategories) {
        this.interestCategories = interestCategories;
    }

    public int getRadiusKm() {
        return radiusKm;
    }

    public void setRadiusKm(int radiusKm) {
        this.radiusKm = radiusKm;
    }
}
