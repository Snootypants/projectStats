# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ProjectStats App                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                            UI Layer                                  │  │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐             │  │
│   │  │ TabShell │  │ HomeView │  │Workspace │  │ Settings │             │  │
│   │  │   View   │  │Dashboard │  │   View   │  │   View   │             │  │
│   │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘             │  │
│   └───────┼─────────────┼─────────────┼─────────────┼────────────────────┘  │
│           │             │             │             │                       │
│   ┌───────┴─────────────┴─────────────┴─────────────┴────────────────────┐  │
│   │                         ViewModel Layer                              │  │
│   │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐     │  │
│   │  │ TabManager │  │ Dashboard  │  │ Terminal   │  │  Settings  │     │  │
│   │  │ ViewModel  │  │ ViewModel  │  │ TabsVM     │  │ ViewModel  │     │  │
│   │  └────────────┘  └────────────┘  └────────────┘  └────────────┘     │  │
│   └───────────────────────────┬──────────────────────────────────────────┘  │
│                               │                                             │
│   ┌───────────────────────────┴──────────────────────────────────────────┐  │
│   │                         Service Layer                                │  │
│   │                                                                      │  │
│   │  ┌─────────────────────┐  ┌─────────────────────┐                   │  │
│   │  │   Data Services     │  │ Integration Services│                   │  │
│   │  │  ─────────────────  │  │  ──────────────────  │                   │  │
│   │  │  ProjectScanner     │  │  ClaudePlanUsage    │                   │  │
│   │  │  GitService         │  │  ClaudeUsageService │                   │  │
│   │  │  TimeTrackingService│  │  GitHubService      │                   │  │
│   │  │  AchievementService │  │  MessagingService   │                   │  │
│   │  └─────────────────────┘  └─────────────────────┘                   │  │
│   │                                                                      │  │
│   │  ┌─────────────────────┐  ┌─────────────────────┐                   │  │
│   │  │   Sync Services     │  │  Utility Services   │                   │  │
│   │  │  ─────────────────  │  │  ──────────────────  │                   │  │
│   │  │  SyncEngine         │  │  NotificationService│                   │  │
│   │  │  CloudKitContainer  │  │  BackupService      │                   │  │
│   │  │  OfflineQueueManager│  │  SecretsScanner     │                   │  │
│   │  │  SyncScheduler      │  │  KeychainService    │                   │  │
│   │  └─────────────────────┘  └─────────────────────┘                   │  │
│   └───────────────────────────┬──────────────────────────────────────────┘  │
│                               │                                             │
│   ┌───────────────────────────┴──────────────────────────────────────────┐  │
│   │                          Data Layer                                  │  │
│   │  ┌────────────────────────────────────────────────────────────────┐ │  │
│   │  │                      SwiftData Models                          │ │  │
│   │  │  CachedProject, TimeEntry, SavedPrompt, SavedDiff,            │ │  │
│   │  │  AISessionV2, ClaudeUsageSnapshot, AchievementUnlock, ...     │ │  │
│   │  └────────────────────────────────────────────────────────────────┘ │  │
│   │                               │                                      │  │
│   │                    ┌──────────┴──────────┐                          │  │
│   │                    │   CloudKit Sync     │                          │  │
│   │                    │   (Private DB)      │                          │  │
│   │                    └─────────────────────┘                          │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Design Patterns

### MVVM (Model-View-ViewModel)

The app follows MVVM architecture:

- **Models**: SwiftData `@Model` classes that persist to the local database
- **Views**: SwiftUI views that observe and display state
- **ViewModels**: `ObservableObject` classes that manage business logic and expose state via `@Published` properties

Example flow:
```
User taps refresh → View calls ViewModel.refresh() → ViewModel calls Services →
Services update Models → SwiftData triggers @Query → View updates automatically
```

### Singleton Services

Most services are singletons accessed via `ServiceName.shared`:

```swift
// Service definition
@MainActor
final class ClaudePlanUsageService: ObservableObject {
    static let shared = ClaudePlanUsageService()
    private init() { }
}

// Usage
ClaudePlanUsageService.shared.fetchUsage()
```

**Why Singletons?**
- Services manage app-wide state (e.g., current Claude session)
- Avoids passing service instances through deep view hierarchies
- Ensures consistent state across the app
- Works well with SwiftUI's environment object pattern

### Observer Pattern

State propagation uses multiple mechanisms:

1. **@Published + @StateObject**: ViewModels expose reactive state
2. **@AppStorage**: Settings automatically sync to UserDefaults
3. **SwiftData @Query**: Views automatically update when models change
4. **NotificationCenter**: For cross-component events (e.g., `.enterFocusMode`)

## Data Layer

### SwiftData Models

All persistent data uses SwiftData's `@Model` macro:

```swift
@Model
final class SavedPrompt {
    var id: UUID
    var projectPath: String
    var content: String
    var createdAt: Date
    // ...
}
```

**Model Categories:**
- **Cached Data**: CachedProject, CachedPrompt, CachedWorkLog, CachedCommit
- **User Data**: SavedPrompt, SavedDiff, ProjectNote, TimeEntry
- **AI Data**: AISessionV2, AIProviderConfig, ClaudeUsageSnapshot
- **Analytics**: DailyMetric, ProjectSession, WeeklyGoal, WorkItem
- **Gamification**: AchievementUnlock

### CloudKit Sync

Sync is handled by the `SyncEngine` which:
1. Converts SwiftData models to `CKRecord` objects
2. Pushes local changes to CloudKit private database
3. Pulls remote changes using change tokens
4. Resolves conflicts via `ConflictResolver`

```
Local Change → needsSync flag → SyncScheduler triggers →
SyncEngine.pushLocalChanges() → CKModifyRecordsOperation →
SyncEngine.pullRemoteChanges() → Process CKRecords → Update Models
```

### Local Storage

| Data Type | Storage Location |
|-----------|------------------|
| SwiftData DB | `~/Library/Application Support/projectStats/default.store` |
| Settings | UserDefaults (@AppStorage) |
| OAuth Tokens | Keychain (read from Claude Code's keychain item) |
| Tab State | UserDefaults (JSON encoded) |

## View Layer

### Navigation Structure

```
ProjectStatsApp
├── WindowGroup("main")
│   └── TabShellView
│       ├── TabBarView (Chrome-style tab strip)
│       ├── XPProgressBar
│       └── Tab Content
│           ├── HomeView (when tab.content == .home)
│           ├── ProjectPickerView (when .projectPicker)
│           └── WorkspaceView (when .projectWorkspace)
│               └── IDEModeView
│                   ├── FileBrowserView
│                   ├── FileViewerView
│                   ├── TerminalPanelView
│                   └── Tool Tabs (Prompts, Diffs, Environment)
│
├── MenuBarExtra
│   └── MenuBarView
│
└── Settings
    └── SettingsView (sidebar navigation)
```

### View Hierarchy

The main window uses a tab-based navigation:

- **TabShellView**: Root container managing tab bar and content area
- **TabBarView**: Horizontal tab strip with add/close/drag-reorder
- **HomeView**: Dashboard with stats cards, heatmap, notifications
- **WorkspaceView**: Project-specific view wrapping IDEModeView
- **IDEModeView**: Three-panel layout (explorer, viewer, terminal)

## Service Layer

### Service Categories

**1. Data Services**
- `ProjectScanner` — Discovers projects in code directory
- `GitService` — Git operations (commits, branches, diff)
- `TimeTrackingService` — Human vs AI time tracking
- `AchievementService` — Achievement checking and unlocking

**2. Integration Services**
- `ClaudePlanUsageService` — Anthropic OAuth API for plan usage
- `ClaudeUsageService` — ccusage CLI for token stats
- `GitHubService` — GitHub API for notifications, repo stats
- `MessagingService` — Telegram/Slack/Discord/ntfy

**3. Sync Services**
- `SyncEngine` — CloudKit push/pull operations
- `CloudKitContainer` — Zone and subscription setup
- `OfflineQueueManager` — Queue changes when offline
- `SyncScheduler` — Periodic and on-change sync triggers

**4. Utility Services**
- `NotificationService` — Local and push notifications
- `BackupService` — Zip project backups
- `SecretsScanner` — Detect secrets before commit
- `KeychainService` — Secure credential storage

## Threading Model

### @MainActor

Most services and ViewModels are marked `@MainActor` to ensure UI safety:

```swift
@MainActor
final class ClaudePlanUsageService: ObservableObject {
    // All properties and methods run on main thread
}
```

### Background Tasks

Long-running operations use structured concurrency:

```swift
Task {
    await ProjectScanner.shared.scanProjects()  // Runs on cooperative thread pool
    // UI updates automatically happen on main actor
}
```

### Shell Commands

Shell commands run synchronously but are called from background tasks:

```swift
Task.detached {
    let result = Shell.run("git log ...", at: path)  // Background thread
    await MainActor.run {
        self.updateUI(with: result)  // Back to main thread
    }
}
```

## Error Handling

### Error Display

Errors are typically:
1. Stored in service `@Published var error: String?`
2. Displayed via `.alert()` or inline error views
3. Logged to console with `[ServiceName]` prefix

### Error Recovery

- **Network errors**: Queued for retry (OfflineQueueManager)
- **Sync conflicts**: Resolved by ConflictResolver (server wins by default)
- **Parse errors**: Gracefully ignored with fallback values
- **SwiftData errors**: Model container attempts cleanup and retry

## Key Files Reference

| File | Purpose |
|------|---------|
| `App/ProjectStatsApp.swift` | App entry, scene configuration, service initialization |
| `ViewModels/SettingsViewModel.swift` | All @AppStorage settings |
| `ViewModels/TabManagerViewModel.swift` | Tab state and navigation |
| `Services/TerminalOutputMonitor.swift` | Claude detection, git event handling |
| `Services/CloudKit/SyncEngine.swift` | CloudKit sync operations |
| `Models/AIProvider.swift` | AI model definitions, pricing, thinking levels |
