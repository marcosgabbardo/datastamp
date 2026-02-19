# DataStamp - Bugs Found

## Code Review Results

### 🔴 High Severity

#### 1. Onboarding blocked by notification permission alert
**File:** `DataStampApp.swift:38-40` + `ContentView.swift:118`
**Description:** The `.task` in `DataStampApp` calls `setupNotifications()` which triggers a system alert. The onboarding sheet in `ContentView.onAppear` tries to present simultaneously but is blocked by the system alert. On fresh install, the user sees the notification permission prompt but **never sees onboarding**.
**Impact:** First-time users miss the entire onboarding experience.
**Fix:** Defer notification request until after onboarding is dismissed, or present onboarding in `DataStampApp` before `ContentView` loads.

#### 2. `WidgetData` type redefined in two files — potential linker conflict
**File:** `WidgetService.swift:43-49` + `DataStampWidget.swift:69-76`
**Description:** `WidgetData` and `WidgetItemData` are defined identically in both the main app target and the widget target. If any shared framework is introduced, this will cause a duplicate symbol error. Currently works only because they're in separate targets.
**Impact:** Maintenance hazard, will break if code is refactored into shared module.
**Fix:** Move shared types to a shared framework or use the App Group container exclusively.

#### 3. `verifyHashInBlock` always returns `true` — verification is fake
**File:** `MerkleVerifier.swift:231`
**Description:** The method `verifyHashInBlock` has a comment "If we got here... the timestamp is likely valid" and returns `true` unconditionally at the end. This means **any** OTS file with a Bitcoin attestation will be reported as "verified" regardless of whether the hash actually exists in the block.
**Impact:** False positive verification results. Users may trust invalid proofs.
**Fix:** Implement proper OP_RETURN output parsing or at minimum, verify the Merkle root properly.

#### 4. Race condition in `ContentView.task` calling `checkPendingUpgrades`
**File:** `ContentView.swift:129-131`
**Description:** The `.task` calls `checkPendingUpgrades(items: items)` using the `@Query` `items` which may not be populated yet when the task starts. SwiftData queries are asynchronous, so `items` could be empty on first run.
**Impact:** Pending timestamps may not be checked on app launch.
**Fix:** Add a small delay or observe the query population before triggering the check.

#### 5. Share Extension submits to only ONE calendar server
**File:** `DataStampShareExtension/ShareViewController.swift:154`
**Description:** The Share Extension hardcodes `https://a.pool.opentimestamps.org/digest` instead of using multiple calendars like the main app does. If this single server is down, the timestamp fails silently.
**Impact:** Share Extension timestamps are less redundant than main app timestamps.
**Fix:** Use multiple calendars or at minimum add fallback servers.

---

### 🟡 Medium Severity

#### 6. Hard-coded strings not using `NSLocalizedString` / `String(localized:)`
**File:** Multiple views
**Description:** Most UI strings are hard-coded in English directly in SwiftUI views despite having `Localizable.strings` files. The localization files exist but are not referenced by the views — views use raw strings like `Text("No Timestamps Yet")` instead of `Text("No Timestamps Yet", tableName: "Localizable")` or `String(localized:)`.
**Impact:** pt-BR localization doesn't actually work. The app always shows English.
**Fix:** Use `LocalizedStringKey` or `String(localized:)` throughout, or rely on SwiftUI's automatic `Text("key")` lookup (requires string keys to match exactly).

> **Note:** SwiftUI's `Text("string")` does auto-lookup in `Localizable.strings`, so if the keys match the English strings exactly, localization _should_ work. Verified: the pt-BR file uses English strings as keys, so this **may** actually work if the locale is set. Downgrading to medium — needs runtime testing with pt-BR locale.

#### 7. `DataStampManager` is `@Observable` but uses `@MainActor` — potential deadlock
**File:** `DataStampManager.swift:8-9`
**Description:** `DataStampManager` is marked both `@MainActor` and `@Observable`. All its methods (including network calls like `upgradeTimestamp`) run on the main thread. While the actual network calls are async, the coordination logic blocks the main actor.
**Impact:** UI may freeze briefly during batch operations or multiple upgrades.
**Fix:** Move heavy coordination to a background actor, keep only UI-facing state on `@MainActor`.

#### 8. `DateFormatter` created repeatedly in hot paths
**File:** `PDFExportService.swift` (multiple `formatDate` calls), `QuickCameraView.swift:148`
**Description:** `DateFormatter` is created in methods called frequently (PDF generation, photo capture). `DateFormatter` creation is expensive.
**Impact:** Minor performance hit during PDF generation and batch operations.
**Fix:** Use static/cached `DateFormatter` instances.

#### 9. Missing error handling in `StorageService` directory creation
**File:** `StorageService.swift:14-16, 22-24, 29-31, 36-38`
**Description:** Directory creation uses `try?` silently swallowing errors. If the Documents directory is full or permissions are wrong, subsequent file operations will fail with confusing errors.
**Impact:** Silent failures that are hard to debug.
**Fix:** Propagate directory creation errors or log them.

#### 10. `CameraViewController` doesn't handle authorization status
**File:** `QuickCameraView.swift:185-218`
**Description:** `CameraViewController.setupCamera()` silently fails if camera permission isn't granted. No UI feedback is shown to the user — they just see a black screen.
**Impact:** Confusing UX when camera permission is denied.
**Fix:** Check `AVCaptureDevice.authorizationStatus` and show an appropriate message.

#### 11. `deleteAllData` in SettingsView doesn't delete files from disk
**File:** `SettingsView.swift:127-133`
**Description:** `deleteAllData()` only deletes SwiftData records but doesn't clean up the corresponding files (images, .ots proofs, thumbnails) from the Documents directory.
**Impact:** Orphaned files accumulate on disk, wasting storage.
**Fix:** Call `StorageService.deleteFiles` for each item before deleting from SwiftData.

#### 12. `PhotoItemView` comparison uses `==` on `PhotosPickerItem`
**File:** `BatchTimestampView.swift:308`
**Description:** `loadedImages.contains(where: { $0.photoItem == item })` relies on `PhotosPickerItem` conforming to `Equatable`. The identity semantics of `PhotosPickerItem` equality are undocumented and may not work as expected.
**Impact:** Duplicate photos could be loaded or photos could be skipped in batch mode.
**Fix:** Track loaded items by their `id` or `itemIdentifier` instead.

#### 13. `DispatchQueue.main.asyncAfter` in haptic patterns — not Swift 6 safe
**File:** `HapticManager.swift:86-88, 94-96`
**Description:** Uses `DispatchQueue.main.asyncAfter` with closure capturing `self` in a `@MainActor` class. While this works, it's not idiomatic Swift concurrency and could cause issues with strict concurrency checking in future Swift versions.
**Impact:** Potential compiler warnings in future Swift versions.
**Fix:** Use `Task { try await Task.sleep(for:) }` instead.

#### 14. Notification permission requested before user sees the app
**File:** `DataStampApp.swift:39`
**Description:** `setupNotifications()` requests permission immediately on launch. Apple's guidelines recommend requesting permissions in context (e.g., after explaining why notifications are needed).
**Impact:** Lower opt-in rate for notifications. Apple may reject during App Review.
**Fix:** Defer permission request to a contextual moment (e.g., after first timestamp is created).

---

### 🟢 Low Severity

#### 15. Magic numbers in PDF generation
**File:** `PDFExportService.swift` (throughout)
**Description:** Hard-coded values like `margin = 40`, `y += 65`, `qrSize = 80`, font sizes `28`, `9`, `7`, etc. scattered throughout the PDF rendering code without named constants.
**Impact:** Hard to maintain and adjust PDF layout.
**Fix:** Extract to named constants or a layout configuration struct.

#### 16. `extractCalendarName` uses string matching
**File:** `PDFExportService.swift` (near end)
**Description:** `extractCalendarName` uses `url.contains("alice")` etc. to determine calendar names. Fragile and will break if calendar URLs change.
**Impact:** Wrong calendar name displayed in PDF certificates.
**Fix:** Parse the URL properly or maintain a mapping dictionary.

#### 17. Unused `idString` variable
**File:** `CloudKitSyncService.swift:271`
**Description:** `let idString = record.recordID.recordName.components(separatedBy: "-").first` is computed but never used.
**Impact:** Dead code, minor code smell.
**Fix:** Remove the unused variable.

#### 18. `FlowLayout` defined but never used
**File:** `TagsEditorView.swift:146-191`
**Description:** A custom `FlowLayout` is defined but never used anywhere in the codebase. `InlineTagsView` uses `HStack` instead.
**Impact:** Dead code.
**Fix:** Remove or use it.

#### 19. `.interactiveDismissDisabled()` on OnboardingView prevents dismissal
**File:** `OnboardingView.swift:83`
**Description:** Onboarding cannot be dismissed by swiping down. While intentional, combined with bug #1 (onboarding may not show at all), this means if onboarding somehow gets stuck, the user can't escape.
**Impact:** Minor UX issue.

#### 20. Thumbnail always 200x200 square — doesn't preserve aspect ratio
**File:** `StorageService.swift:133-138`
**Description:** `saveThumbnail` forces a 200x200 square, stretching non-square images.
**Impact:** Thumbnails appear distorted for portrait/landscape photos.
**Fix:** Use `aspectRatio: .fill` or `.fit` and clip to square.

#### 21. No rate limiting on OTS calendar submissions
**File:** `OpenTimestampsService.swift:73-97`
**Description:** `submitToAllCalendars` fires 3 parallel requests with no rate limiting. In batch mode, this could mean dozens of simultaneous requests.
**Impact:** Could get rate-limited by calendar servers.
**Fix:** Add a semaphore or limit concurrent submissions.

#### 22. `VerifyExternalView` hash extraction is fragile
**File:** `VerifyExternalView.swift:336-341`
**Description:** When no original file is provided, the code extracts the hash from OTS data using hardcoded offsets (`headerSize = 31 + 1 + 1`). This assumes a specific OTS format and will break with different hash types or versions.
**Impact:** External verification may fail for non-standard OTS files.
**Fix:** Use the `MerkleVerifier.parseOtsFile` method to extract the hash properly.

#### 23. `colorForTag` duplicated in 3 places
**File:** `TagsEditorView.swift:101-106`, `TagsEditorView.swift:159-164`, `TagsEditorView.swift:253-258`
**Description:** The same `colorForTag` function is copy-pasted in `TagsEditorView`, `SuggestionTagButton`, and `InlineTagsView`.
**Impact:** Code duplication, maintenance burden.
**Fix:** Extract to a shared utility function or extension.

---

## Summary

| Severity | Count |
|----------|-------|
| 🔴 High | 5 |
| 🟡 Medium | 9 |
| 🟢 Low | 9 |
| **Total** | **23** |
