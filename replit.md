# Spark — Project Overview

Spark is a platform for discovering and creating tiny, nearby social plans happening soon ("sparks"). It supports spontaneous, time-bound, location-aware activities like sports, transit sharing, and casual meetups.

## Project Structure

```
/
├── index.html          # Static web prototype (served at port 5000)
├── script.js
├── styles.css
├── spark_flutter/      # Flutter mobile app (main product)
├── spark_backend/      # Spring Boot backend (Java 21, Redis + PostgreSQL)
└── SparkIOS/           # Native iOS app (SwiftUI)
```

## Running the Web Prototype

A workflow serves the static site at port 5000 using Python's HTTP server:
```
python3 -m http.server 5000
```

## Flutter App (`spark_flutter/`)

**Tech Stack:** Flutter 3, Riverpod, Dio, Firebase, Geolocator, Google Fonts (Manrope)

**Architecture:** Feature-based clean architecture
```
lib/
├── core/           # Theme, auth, network, analytics, push
├── features/
│   ├── auth/       # Phone login
│   ├── chat/       # Chat inbox and messaging
│   ├── profile/    # User profile and notification preferences
│   └── spark/      # Core: discovery, creation, details
├── shared/         # App widget, navigation, reusable widgets
└── main.dart
```

**Navigation:** 4-tab bottom nav (Discover, Create, Chat, Profile)

## UI/UX Improvements Applied

1. **Color consistency** — Nav bar active color now uses `AppColors.accent` (deep navy #2F426F) throughout, no more rogue blue
2. **Profile as 4th tab** — Profile moved from a hidden top-right icon to a proper bottom nav tab
3. **Slim category chips** — Replaced 92px tall category tiles with compact horizontal pill chips (~36px)
4. **Pull-to-refresh** — `RefreshIndicator` added to the discover feed; pull down to reload
5. **Infinite scroll** — Auto-loads next page when scrolling near the bottom; removed manual "Load More" button
6. **Better empty state** — Icon, friendly message, and CTA when no sparks match filters
7. **Nav bar shadow** — Elevated shadow above the bottom bar to clearly separate it from content
8. **Dark mode** — Full dark theme defined in `AppTheme.dark`; respects system setting automatically

## Backend (`spark_backend/`)

Spring Boot 3, Java 21, Redis (live sparks with TTL + geo-index), PostgreSQL (durable data), Flyway migrations.
Run with Docker Compose + `./mvnw spring-boot:run`.
