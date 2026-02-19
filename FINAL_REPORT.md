# DataStamp - Review & Test Report

## Summary

| Metric | Value |
|--------|-------|
| **Code quality** | 7/10 |
| **Bugs found** | 23 (High: 5, Medium: 9, Low: 9) |
| **Test coverage** | 52% of identified flows (86% of testable flows) |
| **Critical issues** | 2 (onboarding blocked, verification always returns true) |
| **Unit tests** | 21/21 passing ✅ |
| **Build** | Clean (0 errors, 0 warnings) ✅ |
| **Dependencies** | 0 (fully self-contained) ✅ |

---

## Technical Stack
- **SwiftUI** + **SwiftData** + **Swift 6** (strict concurrency)
- iOS 17.0+, Xcode 16+
- Zero third-party dependencies
- Actor-based services, @Observable manager pattern
- OpenTimestamps protocol + Bitcoin blockchain verification
- English + Portuguese (pt-BR) localization

---

## Code Review Highlights (Top 5 Issues)

### 1. 🔴 Onboarding Never Shows (High)
The notification permission request fires in `DataStampApp.task` before `ContentView.onAppear` can present the onboarding sheet. First-time users skip onboarding entirely.

### 2. 🔴 Fake Verification (High)
`MerkleVerifier.verifyHashInBlock()` always returns `true` at the end, meaning any OTS file with a Bitcoin attestation tag is reported as "verified" without actually checking the blockchain proof chain.

### 3. 🔴 Share Extension Single Calendar (High)
The Share Extension submits to only `a.pool.opentimestamps.org` while the main app uses 3 calendars (alice, bob, finney). Single point of failure for share extension timestamps.

### 4. 🟡 Localization Not Working (Medium)
UI strings are hardcoded in English. `Localizable.strings` files exist for pt-BR but may not be referenced correctly at runtime (SwiftUI auto-lookup depends on exact key matching).

### 5. 🟡 Main Thread Coordination (Medium)
`DataStampManager` is `@MainActor` but performs all coordination including network-dependent logic on the main thread. Batch operations and upgrade checks could cause UI freezes.

---

## E2E Test Results

| Result | Count | Details |
|--------|-------|---------|
| ✅ Passed | 12 | Build, launch, empty state, unit tests, nav, FAB, widgets |
| ❌ Failed | 5 | Onboarding, notification timing, create blocked, camera fallback, localization |
| ⚠️ Blocked | 5 | Settings, folders, verify, create timestamp, detail view |
| 🚫 N/A | 4 | Camera, share ext, widget, Siri, background tasks, iCloud |

**Main blocker:** Notification permission alert prevents all UI interaction on simulator. Fix: defer `requestAuthorization()` call.

---

## Recommendations

### Priority Fixes (do first)
1. **Defer notification permission** — Move from `DataStampApp.task` to after onboarding is dismissed or after first timestamp creation
2. **Fix onboarding presentation** — Ensure onboarding sheet presents before any system alerts
3. **Implement real verification** — `verifyHashInBlock` should actually check OP_RETURN outputs or merkle root
4. **Share Extension redundancy** — Submit to multiple calendars like the main app

### Architectural Improvements
1. **Move coordination off @MainActor** — Create a background actor for network coordination, keep only UI state on main
2. **Shared framework for types** — Move `WidgetData`, `ContentType`, `DataStampStatus` to a shared framework between app, widget, and share extension
3. **Proper localization** — Use `String(localized:)` or `LocalizedStringResource` throughout, test with pt-BR locale
4. **Error propagation** — Replace `try?` in `StorageService` directory creation with proper error handling

### Testing Gaps
1. **No UI tests** — Add XCUITest for critical flows (create timestamp, view detail, share)
2. **No network mocking** — Unit tests don't mock URLSession; add protocol-based dependency injection
3. **No integration tests** — SwiftData + OTS service integration untested
4. **No accessibility tests** — A11y labels exist but no automated VoiceOver testing
5. **No dark mode testing** — Not verified
6. **No iPad layout testing** — iPad is supported but layout not verified

---

## Overall Assessment

DataStamp is a **well-architected, feature-rich iOS app** with an impressive amount of functionality for a v1.0. The codebase demonstrates strong Swift 6 practices (strict concurrency, actors, Sendable), modern SwiftUI patterns, and zero dependency philosophy.

**Strengths:**
- Clean architecture with proper separation of concerns
- Comprehensive feature set (timestamps, batch, camera, PDF, widget, share extension, Siri)
- Good unit test foundation (21 tests, all passing)
- Proper accessibility labels and haptic feedback
- Privacy-first design (only hashes leave the device)

**Weaknesses:**
- Critical UX bug (onboarding blocked by notification alert)
- Verification is a stub (always returns true)
- Localization may not work at runtime
- No UI/E2E test automation
- Some code duplication and dead code

**Recommendation:** Fix the 5 high-severity bugs before any App Store submission. The architectural foundation is solid — these are mostly quick fixes.
