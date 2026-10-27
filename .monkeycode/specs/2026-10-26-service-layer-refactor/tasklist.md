# AppState Service Layer Refactor — Tasklist

## Phase 1: Foundation (pure extraction, zero caller changes)

- [ ] **1.1** Create `lib/core/session_service.dart` — SessionService (login/logout/me/cookies)
- [ ] **1.2** Create `lib/core/services/checkin_service.dart` — CheckinService (sign/checkin + logging)
- [ ] **1.3** Create `lib/core/services/reply_service.dart` — ReplyService (auto-reply/manual reply/dedup/quota)
- [ ] **1.4** Create `lib/core/storage/settings_repository.dart` — SettingsRepository (SharedPreferences access)
- [ ] **1.5** Slim AppState — delegate to services, keep same public API
- [ ] **1.6** Update background_checkin.dart to use new services directly
- [ ] **1.7** Update tests if needed (constructor changes)

## Phase 2: Verification

- [ ] **2.1** `flutter analyze` — 0 issues
- [ ] **2.2** `flutter test` — all tests pass
- [ ] **2.3** `dart run tool/parse_test.dart` — parser regression

## Phase 3: Commit

- [ ] **3.1** Commit all changes
