# AppState Service Layer Refactor — Design

## Goal

Decompose the 772-line `AppState` God Object into focused services and a slim UI-state-only notifier, while preserving all existing behavior.

## Current Problem

`AppState` extends `ChangeNotifier` and simultaneously:
- Holds business services (`DiscuzClient`, `ForumApi`, `PreviewStore`, `AutomationEngine`, `AutoReplyQueue`)
- Manages UI state (`boards`, `threads`, `signStatus`, `replyLogs`)
- Reads/writes `SharedPreferences` for every setting
- Stores sensitive data in plaintext (`AppSettings.savedPassword`, cookies)
- Implements business logic (login, checkin, auto-reply, purchase)

## Target Architecture

```
main.dart
  └─ AppState (slim, UI state only)
       ├─ SessionService        login/logout/cookie persistence/user
       ├─ CheckinService        checkin ops + scheduling + logging
       ├─ ReplyService          auto-reply decision/dedup/quota/manual reply
       └─ SettingsRepository    SharedPreferences read/write (no UI)

data/
  └─ forum_api.dart            ForumApi (unchanged)
core/
  ├─ discuz_client.dart        DiscuzClient (unchanged)
  ├─ automation/
  │    ├─ automation_engine.dart   (unchanged)
  │    ├─ checkin_service.dart     (absorbed into CheckinService)
  │    ├─ auto_reply_queue.dart    (absorbed into ReplyService)
  │    └─ background_checkin.dart  (unchanged)
  ├─ storage/
  │    ├─ automation_models.dart   (unchanged)
  │    └─ settings_repository.dart (NEW)
  ├─ session_service.dart        (NEW)
  └─ services/
       ├─ checkin_service.dart    (NEW — replaces core/automation/checkin_service.dart)
       └─ reply_service.dart      (NEW)
```

## Module Boundaries

### SettingsRepository
- Owns all `SharedPreferences` access
- Exposes typed getters/setters for `AppSettings`, reply logs, checkin logs, replied TIDs, reply counter
- No Flutter UI imports

### SessionService
- Owns `DiscuzClient` lifecycle
- `login(username, password, remember)`, `logout()`, `loadMe()`
- Persists cookies via `SharedPreferences` (delegates to SettingsRepository)
- Emits `onUserChange` callback to notify AppState

### CheckinService
- Merges current `checkin_service.dart` scheduling logic with `AppState.signNow()`
- Manages checkin logs (persist via SettingsRepository)
- Exposes `signNow()`, `autoSignIfNeeded()`, `checkinLogs` getter
- Owns the `CheckinScheduler` instance

### ReplyService
- Merges current `auto_reply_queue.dart` queue logic with `AppState.maybeAutoReply()` / `manualReply()` / `buyThread()`
- Manages reply logs, dedup TIDs, reply counter (via SettingsRepository)
- Owns `AutomationEngine` for preset selection

### AppState (after refactor)
- UI state: `boards`, `threads`, `currentFid`, `currentTid`, `currentThreadId`, `isLoginLoading`, `loginError`
- Settings state: `AppSettings settings` (mirrors from SettingsRepository, notifies listeners)
- Service references: `session`, `checkin`, `reply`, `settingsRepo`
- Thin delegates that wire service callbacks → `notifyListeners()`

## Sensitive Data

- `savedPassword` stays in SharedPreferences for now (Flutter `flutter_secure_storage` requires native platform channels that may break Web/Linux/macOS targets). Document as tech debt with a TODO.
- Cookies remain in SharedPreferences (existing behavior, low risk — they are session tokens, not credentials).

## Migration Strategy

1. Create SettingsRepository — pure data access
2. Create SessionService — login/logout/me
3. Create CheckinService — sign/checkin
4. Create ReplyService — reply/automation
5. Slim AppState — delegate to services, keep UI state
6. Update all callers (pages that reference `state.signNow()` etc.)
7. Run analyze + tests

## Constraints

- No behavior changes
- `flutter analyze` must pass with 0 issues
- All 11 offline test files must pass
- Parser layer stays pure Dart
