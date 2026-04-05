# Spark App — Project Memory

## Overview
**Spark** is a hyperlocal real-time meetup/event platform.
Users create short-lived "Sparks" (meetup events), discover nearby ones, and join them.

## Architecture
- **Flutter** mobile app (Riverpod + Dio + Firebase Auth) — `spark_flutter/`
- **Spring Boot** backend (PostgreSQL + Redis + Flyway + JWT + Gemini AI moderation) — `spark_backend/`
- **SparkIOS** — native iOS project (separate)
- 9 Flyway DB migrations

## Core Features
- Phone-number OTP auth (Firebase-backed)
- Create Sparks (categories: Sports, Study, Ride, Events, Hangout)
- Discover nearby Sparks (Redis geo-index)
- Join / Leave / Cancel Sparks
- AI content moderation (Gemini)
- Push notifications (FCM)
- Groups / Circles / Invite visibility levels
- Chat per Spark
- Activity / Profile screens

## Code Review — Fixed Issues (Session 1 + Session 2)

### Critical Fixes (Session 1)
1. `application.yml` — `expose-debug-otp` and `enable-dev-guest-login` defaults → `false`
2. `application.yml` — `ddl-auto: update` → `validate`
3. `SparkService.java` — Past-time validation for `startsAt`
4. `discover_screen.dart` — Removed hardcoded "Saurav"
5. `push_registration_service.dart` — Fixed endpoint `/auth/device-token` → `/api/v1/push/devices`
6. `PhoneAuthService.java` — Redis OTP rate limiting (5/hour per phone)
7. `SparkService.java` — `cancelSpark` `@Transactional` + `liveSparkCacheService.remove()`
8. `SecurityConfig.java` — CORS configuration added

### Medium/Low Fixes (Session 1)
9-23: JWT warning, visibility in NearbySparkResponse, AI prompt injection hardening, DataSeeder fix,
      auth persistence (SharedPreferences), ThemeMode.system, Empty state CTA, category colors,
      SparkCategory.fromString(), error logging in catch blocks

### Delete Account Flow (Session 3)
27. Added `deleteByUserId`, `deleteBySparkId`, `deleteByGroupId`, `deleteByUser`, etc. to 8 repositories
28. `AccountDeletionService.java` — new service: Redis eviction + 12-step transactional cascade delete
29. `UserController.java` — `DELETE /api/v1/users/me` endpoint added (204 No Content)
30. `auth_api_repository.dart` — `deleteAccount()` calls `DELETE /api/v1/users/me`
31. `auth_controller.dart` — `deleteAccount()`: unregister FCM → backend delete → Firebase signOut → clear session
32. `profile_screen.dart` — "Delete account" row below Sign Out; confirmation dialog with bullet list of what's deleted, loading overlay during deletion, error snackbar on failure

### Three New Features (Session 4)

**1. Shareable Deep Links**
- Backend: `GET /api/v1/sparks/{id}/public` (no-auth preview endpoint) — `SecurityConfig` updated
- Backend: `shareUrl` (`spark://sparks/{id}`) added to `SparkResponse`
- Flutter: `share_plus` upgraded from clipboard → native share sheet (`Share.share`)
- Flutter: `app_links ^6.3.4` added; `SparkApp` initialises AppLinks stream on startup
- Flutter: Deep link handler → `pendingDeepLinkSparkIdProvider`; `RootShell` navigates to detail
- Android: `AndroidManifest.xml` — intent filter for `spark://sparks/{sparkId}`

**2. Recurring Sparks (Templates)**
- DB: `V10__recurring_sparks.sql` — recurrence columns on `spark_events`
- Backend: `RecurringSparkJob` — `@Scheduled` hourly, spawns instances for due templates
- Backend: Recurrence fields propagated through `CreateSparkCommand` → `CreateSparkRequest` → Entity
- Flutter: `_RecurrenceSection` widget in Create screen (toggle + Daily/Weekly + day picker + end date)
- Flutter: Recurring badge on nearby spark cards

**3. Proactive Nearby Alerts**
- Backend: `UserLocationService` — Redis GEO set + active sorted set for user locations
- Backend: `SparkController.nearby()` — caches user location on every query
- Backend: `NearbyAlertJob` — `@Scheduled` every 15 min, finds new sparks, pushes to nearby users with dedup
24. `push_registration_service.dart` — `unregisterDeviceToken()` added (DELETE /api/v1/push/devices)
25. `auth_controller.dart` — `logout()` method: unregisters FCM token, Firebase signOut, clears session
26. `profile_screen.dart` — "Sign out" row in Account section with confirmation dialog
    Full chain: logout() → session=null → SparkApp listener → SharedPreferences.clear() → PhoneLoginScreen

### Critical Fixes
1. `application.yml` — `expose-debug-otp` and `enable-dev-guest-login` defaults changed from `true` → `false`
2. `application.yml` — `ddl-auto: update` → `validate` (prevents Flyway + Hibernate conflict)
3. `SparkService.java` — Added past-time validation for `startsAt` (isBefore now-60s)
4. `discover_screen.dart` — Removed hardcoded "Saurav"; now reads from `authSessionProvider`
5. `push_registration_service.dart` — Fixed API endpoint `/auth/device-token` → `/api/v1/push/devices`
6. `PhoneAuthService.java` — Added Redis-based OTP rate limiting (5 req/hour per phone)
7. `SparkService.java` — `cancelSpark` marked `@Transactional` + now calls `liveSparkCacheService.remove()`
8. `SecurityConfig.java` — Added CORS configuration (all origins, all standard methods)

### Medium Fixes
9. `JwtService.java` — Startup warning if default JWT secret used; minimum 32-byte enforcement
10. `LiveSparkCacheService.java` — `visibility` added to `LiveSpark` and `NearbyLiveSpark` records + Redis hash
11. `SparkController.java` — `visibility` added to `NearbySparkResponse`; nearby() maps it correctly
12. `AiModerationService.java` — XML tags around user input to prevent prompt injection
13. `DataSeeder.java` — Idempotency now checks `users.count() > 0` (simpler and correct)
14. `auth_state.dart` — Added `toJson()`/`fromJson()` to `AuthSession`
15. `auth_persistence_service.dart` — New file; persists auth session to `SharedPreferences`
16. `main.dart` — Loads persisted session before `runApp`; passes as `ProviderScope` override
17. `spark_app.dart` — Session persistence listen + `ThemeMode.system` (was hardcoded `light`)

### Low Priority Fixes
18. `discover_screen.dart` — `_EmptyState` CTA now navigates to Create tab (was `onPressed: null`)
19. `discover_screen.dart` — `_catColor`/`_catBg` now use `cat.accentColor` (was always `AppColors.accent`)
20. `create_spark_screen.dart` — `_categoryAccentColor` uses `cat.accentColor` (was always `neutralSurface`)
21. `spark.dart` — `SparkCategory.fromString()` static helper added
22. `spark_api_repository.dart` — Both category parsing sites now use `SparkCategory.fromString()`
23. `spark_controller.dart` — All `catch (_) {}` blocks now log errors via `debugPrint`

## Backlog (P1 — Not Yet Fixed)
- `savedLocationsProvider` and `recentLocationsProvider` still return hardcoded Bangalore locations
- `_coordsFor()` geocoding still hardcoded to Bangalore neighborhoods
- `_isManualMode` always `true` — dead auto-mode code (~400 lines) not cleaned up
- `AnalyticsService` still a console-print stub; no real analytics platform integrated
- `SparkCategory` stored as raw `String` in `SparkEventEntity` (not `@Enumerated(EnumType.STRING)`)
- No proper logout flow; session cleared only via provider state = null
- Redis fallback to DB for cold cache not yet implemented

## P2 / Future
- Dark mode properly tested
- Recent searches tracked via SharedPreferences
- Rate limiting for other abusable endpoints (join, create)
- Backend admin panel
