# Spark – Product Requirements Document

## Overview
**Spark** is a hyperlocal real-time meetup/event platform. Users discover, create, and join spontaneous events ("sparks") happening nearby. It features group chat per event, location-based filtering, and safety moderation.

**Stack**: Flutter (mobile) + Spring Boot (Java) backend + PostgreSQL + Redis + Firebase Auth + FCM  
**Other artefacts**: Static HTML landing page, iOS native app (SparkIOS)

---

## Architecture
- `spark_flutter/` — Flutter mobile app (Riverpod state management)
- `spark_backend/` — Spring Boot backend (REST API + WebSocket chat)
- `SparkIOS/` — Native iOS app (Swift/UIKit)
- `index.html / styles.css / script.js` — Marketing landing page

---

## Completed Work

### Session 1 – Pre-launch Bug Fixes & Polish (Feb 2026)

#### Bug Fixes
1. **Chat `isMine` always `false`** (CRITICAL)
   - `chatThreadsProvider` now uses record family key `(sparkId, currentUserId)`
   - `_toUiMessage` compares `msg.senderId == _currentUserId` for correct bubble side
   - File: `lib/features/chat/presentation/controllers/chat_controller.dart`

2. **Chat timestamp formatting** – minutes now zero-padded, 12-hr AM/PM format
   - File: `chat_controller.dart` → `_formatTimestamp()`

3. **Discover screen error text colour** – was `AppColors.accent` (navy) on red background; fixed to `AppColors.errorText`
   - File: `lib/features/spark/presentation/screens/discover_screen.dart`

4. **"Custom" time chip never shows selected** – was hardcoded `selected: false`; now computes `diff > 65 minutes`
   - File: `lib/features/spark/presentation/screens/create_spark_screen.dart`

5. **Default location `'Indiranagar'`** – changed to `'Near you'` for global users
   - File: `lib/features/spark/presentation/controllers/spark_controller.dart`

6. **Unnecessary AI parse on init** – removed `_scheduleAiParse()` from `addPostFrameCallback` and cleared hardcoded placeholder `'Cricket at 6 near Central Park'` from `_planController` initial text
   - File: `create_spark_screen.dart`

7. **Dead `ctaHint = null` block** – removed unused `ctaHint` variable and its dead `if (ctaHint != null)` widget block
   - File: `create_spark_screen.dart`

#### Dead Code Cleanup
- `_HeaderAction` widget removed from `chat_inbox_screen.dart`
- `_MetaInline` widget removed from `spark_detail_screen.dart`
- `_formatNow()` method removed from `chat_screen.dart`
- `_initialMessages()` and `_nameFromInitial()` methods removed from `chat_screen.dart`

#### UI/UX Polish
- **Chat empty state** – blank chat now shows icon + "No messages yet / Be the first to say hi!"
- **Chat auto-scroll to bottom** – `ref.listen` scrolls to bottom when history first loads; `_sendMessage` scrolls after each sent message
- **Chat date separators** – helper methods `_buildMessageItems`, `_isSameDay`, `_dateLabelFor`, `_buildDateSeparator` inserted; messages grouped under "Today / Yesterday / Jan 15" headers
- **`ChatMessage` model** – added `createdAt: DateTime` field used for date grouping
- **Location catalog** – made generic (city-agnostic options first: "Current location", "Downtown", "Campus", etc.) with Bangalore-specific ones at the bottom
- **Recent locations** – changed from Bangalore-specific to generic (`'Downtown'`, `'City Center'`, `'Campus'`)

---

## Backlog / P1 (Next Sprint)
- [ ] Persist recent searches via SharedPreferences
- [ ] Real geocoding for non-Bangalore locations (`_coordsFor()` is still hardcoded)
- [ ] Optimistic message UI (show message instantly before API round-trip)
- [ ] Push notification (FCM) integration end-to-end test
- [ ] Spring Boot backend deployment to cloud
- [ ] App Store / Play Store submission checklist
- [ ] iOS build + TestFlight distribution

## P2 / Future
- [ ] Read receipts in chat
- [ ] Scroll-to-bottom FAB when user has scrolled up in chat
- [ ] Timing filter sent to backend (currently client-side only)
- [ ] In-memory `lockedSparkIdsProvider` → persisted backend state
