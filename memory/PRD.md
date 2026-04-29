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
_(see full list above)_

### Session 2 – Chat Revamp + Launch Readiness (Feb 2026)

#### Chat — WhatsApp-Quality Revamp
- Full rewrite of `chat_screen.dart` in correct **light theme** with gray canvas `#F0F2F5`
- WhatsApp-style bubble tails, white incoming bubbles with shadow, navy own bubbles
- Category emoji badge in app bar, colored sender names per-user, avatars
- Animated mic→send button, multi-line input, double-tick sent indicator
- Chat inbox also revamped (emoji badges, light theme consistency)

#### Haptic Feedback + Pop Animation
- `HapticFeedback.lightImpact()` on every message send
- `_PopIn` widget: `AnimationController` with `Curves.easeOutBack` (slight overshoot)
  wraps every `_MessageBubble` via `ValueKey(message.id)` — plays once on entry
- File: `chat_screen.dart`

#### Optimistic Message UI
- `isPending: bool` added to `ChatMessage` model (default `false`)
- `sendMessage()` now adds temp message instantly with `isPending: true`  
- On API success: replaces temp with confirmed server message
- On API failure: removes temp (user sees message disappear = send failed)
- Pending indicator: small `CircularProgressIndicator` instead of double-tick
- File: `chat_controller.dart`

#### Real Geocoding (`_coordsFor()`)
- Replaced hardcoded Bangalore-only lookup with async geocoding
- "Near you" / "Current location" → `Geolocator.getCurrentPosition()` with permission flow
- Named locations → `geocoding.locationFromAddress()` (platform native geocoding)
- Fallback: Bangalore center `(12.9716, 77.5946)` if both fail
- All 4 callers (`refreshNearby`, `fetchNextNearbyPage`, `createSpark`, `updateSpark`) updated to `await`
- File: `spark_controller.dart`

#### Persistent Recent Searches
- New `SearchHistoryService` backed by `SharedPreferences` (key: `spark_recent_searches`, max 8)
- `searchHistoryProvider` (StateNotifierProvider) loads on init, updates on add/remove/clear
- `_SearchScreen` converted from `StatefulWidget` → `ConsumerStatefulWidget`
- Each history chip shows a × delete button + "Clear all" link
- Saves on every explicit search submit (not on back navigation)
- File: `search_history_service.dart` (new), `discover_screen.dart`

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
- **Chat empty state** – blank chat now shows spark category emoji + "No messages yet / Be the first to say hi!"
- **Chat auto-scroll to bottom** – `ref.listen` scrolls to bottom when history first loads; `_sendMessage` scrolls after each sent message
- **Chat date separators** – WhatsApp-style centered pill ("Today / Yesterday / Jan 15") between message groups
- **Chat bubble tails** – WhatsApp-style tail (bottom-right for own, bottom-left for other), 4px radius on tail corner
- **Incoming bubble shadow** – subtle drop shadow on white bubbles against gray canvas
- **Colored sender names** – each participant gets a unique color from a 6-color palette (like WhatsApp groups)
- **Avatar on last bubble** – small initials circle shown next to the last message in each group
- **Animated send/mic button** – mic icon when field is empty, animated transition to send arrow when typing (with color change)
- **Multi-line input** – text field expands up to 120px, then scrolls
- **Double-tick icon** – visual sent indicator on own messages
- **Category emoji badge** – app bar shows spark category emoji in category-tinted circle
- **`ChatMessage` model** – added `createdAt: DateTime` field used for date grouping
- **Chat background** – subtle warm-gray (`#F0F2F5`) matching WhatsApp's chat canvas (not pure white)
- **Chat inbox** – emoji badges replacing icon badges, consistent light theme, improved empty state with navy colors
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
