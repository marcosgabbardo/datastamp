# DataStamp - Technical Review

## Purpose
DataStamp is an iOS app that creates **cryptographic timestamp proofs** using the [OpenTimestamps](https://opentimestamps.org) protocol. Users can timestamp text, photos, or files, which are hashed (SHA-256) and submitted to OpenTimestamps calendar servers. The hash is eventually anchored in the **Bitcoin blockchain**, providing an immutable proof that the content existed at a specific point in time.

## Technical Stack
| Component | Technology |
|-----------|-----------|
| **UI Framework** | SwiftUI |
| **Data Persistence** | SwiftData (`ModelContainer` / `ModelContext`) |
| **Concurrency** | Swift Concurrency (async/await, actors, `@Sendable`) |
| **Swift Version** | 6.0 with `SWIFT_STRICT_CONCURRENCY: complete` |
| **Min Deployment** | iOS 17.0 |
| **Xcode** | 16.0+ |
| **Crypto** | CryptoKit (SHA-256, SHA-1) |
| **Networking** | URLSession (OpenTimestamps API, Blockstream API) |
| **Project Gen** | XcodeGen (`project.yml`) |
| **Architecture** | MVVM-ish (Manager pattern as ViewModel) |
| **Signing** | Automatic, Team: 84P86W64VJ |

## Dependencies
**Zero third-party dependencies.** Uses only Apple frameworks:
- SwiftUI, SwiftData, CryptoKit, UIKit, AVFoundation
- PhotosUI, UniformTypeIdentifiers, WidgetKit
- CloudKit (configured but disabled), BackgroundTasks
- AppIntents (Siri Shortcuts)

## Project Structure
```
DataStamp/
├── DataStampApp.swift              # App entry point, ModelContainer setup
├── ContentView.swift               # Main list view + empty state + FAB
├── Info.plist                      # Camera & photo library usage descriptions
├── DataStamp.entitlements          # App Groups
├── Models/
│   └── DataStampItem.swift         # SwiftData models (DataStampItem, Folder, enums)
├── Views/
│   ├── OnboardingView.swift        # 4-page onboarding
│   ├── CreateTimestampView.swift   # Text/Photo/File creation + CameraView
│   ├── BatchTimestampView.swift    # Multi-item timestamping
│   ├── ItemDetailView.swift        # Detail + status + share + PDF
│   ├── SettingsView.swift          # iCloud toggle, about, delete all
│   ├── VerifyExternalView.swift    # Import & verify .ots files
│   ├── MerkleTreeView.swift        # Visual Merkle path display
│   ├── QuickCameraView.swift       # Fast camera capture + timestamp
│   ├── FolderListView.swift        # Folder management (CRUD)
│   ├── FolderPickerView.swift      # Assign folder to item
│   └── TagsEditorView.swift        # Tag management + suggestions
├── Services/
│   ├── DataStampManager.swift      # Main coordinator (@Observable, @MainActor)
│   ├── OpenTimestampsService.swift # OTS protocol implementation (actor)
│   ├── MerkleVerifier.swift        # OTS file parsing & verification (actor)
│   ├── StorageService.swift        # Local file storage (actor)
│   ├── PDFExportService.swift      # Certificate PDF generation
│   ├── CloudKitSyncService.swift   # iCloud sync (disabled)
│   ├── BackgroundTaskManager.swift # BGTaskScheduler for upgrades
│   ├── NotificationService.swift   # Local notifications (actor)
│   └── WidgetService.swift         # Widget data updates
├── Utilities/
│   ├── HapticManager.swift         # Centralized haptics
│   └── AccessibilityModifiers.swift # A11y helpers
├── Intents/
│   └── DataStampIntents.swift      # Siri Shortcuts integration
└── Resources/
    ├── Assets.xcassets/            # App icon, colors
    ├── en.lproj/Localizable.strings
    └── pt-BR.lproj/Localizable.strings

DataStampShareExtension/            # Share sheet extension (UIKit)
DataStampWidget/                    # Home screen widget (WidgetKit)
DataStampTests/                     # Unit tests (Swift Testing)
```

## Key Architectural Decisions
1. **Actor-based services** — StorageService, OpenTimestampsService, MerkleVerifier, NotificationService are all actors for thread safety
2. **@MainActor DataStampManager** — Central coordinator marked `@Observable` for SwiftUI integration
3. **SwiftData** — Native Apple persistence, no Core Data migration needed
4. **Zero dependencies** — No SPM/CocoaPods, fully self-contained
5. **Localization** — English + Portuguese (pt-BR) via `Localizable.strings`
6. **Strict concurrency** — Swift 6 complete concurrency checking enabled

## App Features
1. **Text/Photo/File Timestamping** — Hash content, submit to OTS calendars
2. **Batch Timestamping** — Multiple items at once
3. **Quick Camera** — Instant photo capture + timestamp
4. **Automatic Upgrades** — Background task checks for Bitcoin confirmations
5. **PDF Certificates** — Professional certificate export
6. **External Verification** — Import and verify .ots files
7. **Merkle Path Visualization** — Shows the cryptographic proof chain
8. **Share Extension** — Timestamp from any app via Share Sheet
9. **Home Screen Widget** — Shows pending/confirmed counts
10. **Siri Shortcuts** — Voice commands for timestamping
11. **Folders & Tags** — Organization system
12. **iCloud Sync** — Implemented but disabled (needs paid developer account)
13. **Haptic Feedback** — Rich haptics for all interactions
14. **Accessibility** — VoiceOver labels and hints
