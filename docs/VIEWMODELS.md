# ViewModels

## Overview

ViewModels manage state and business logic for views. Most are singletons accessed via `ViewModel.shared` and conform to `ObservableObject`.

**Total ViewModels:** 7

---

## SettingsViewModel

**File:** `ViewModels/SettingsViewModel.swift`
**Type:** Singleton (`SettingsViewModel.shared`)
**Conforms to:** ObservableObject

**Purpose:** Manages all app settings via @AppStorage

### Enums

**Editor:**
| Case | Display Name |
|------|--------------|
| vscode | Visual Studio Code |
| xcode | Xcode |
| cursor | Cursor |
| sublime | Sublime Text |
| finder | Finder |

**Terminal:**
| Case | Display Name |
|------|--------------|
| terminal | Terminal |
| iterm | iTerm |
| warp | Warp |

**AppTheme:**
| Case | Description |
|------|-------------|
| system | Follow system appearance |
| light | Always light mode |
| dark | Always dark mode |

### Properties

See [SETTINGS_REFERENCE.md](SETTINGS_REFERENCE.md) for complete @AppStorage keys.

### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| codeDirectory | URL | Code directory as URL |
| defaultEditor | Editor | Default editor enum |
| defaultTerminal | Terminal | Default terminal enum |
| theme | AppTheme | Current theme |
| messagingServiceType | MessagingServiceType | Active messaging provider |
| aiProvider | AIProvider | Legacy AI provider |
| defaultModel | AIModel | Default AI model |
| defaultThinkingLevel | ThinkingLevel | Default thinking level |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `selectCodeDirectory()` | Void | Show folder picker |
| `openInTerminal(_ path: URL)` | Void | Open path in terminal |
| `testNotification()` | Void | Send test notification |
| `applyThemeIfNeeded()` | Void | Apply theme to NSApp |

---

## TabManagerViewModel

**File:** `ViewModels/TabManagerViewModel.swift`
**Type:** Singleton (`TabManagerViewModel.shared`)
**Conforms to:** ObservableObject

**Purpose:** Manages tab state, navigation, and persistence

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| tabs | [AppTab] | All open tabs |
| activeTabID | UUID | Currently active tab |
| favoriteTabProjects | Set<String> | Favorite project paths |

### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| activeTab | AppTab? | Current active tab |
| activeTabIndex | Int? | Index of active tab |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `newTab()` | Void | Open new picker tab |
| `closeTab(_ id: UUID)` | Void | Close tab by ID |
| `closeOtherTabs(keeping id: UUID)` | Void | Close all except one |
| `selectTab(_ id: UUID)` | Void | Switch to tab |
| `selectTab(at index: Int)` | Void | Switch to tab by index |
| `nextTab()` | Void | Go to next tab |
| `previousTab()` | Void | Go to previous tab |
| `moveTab(from: UUID, to: UUID)` | Void | Reorder tabs |
| `openProject(path: String)` | Void | Open project in current tab |
| `navigateBack()` | Void | Go back to picker |
| `isFavorite(_ tab: AppTab)` | Bool | Check if tab is favorite |
| `toggleFavorite(_ tab: AppTab)` | Void | Toggle favorite status |
| `saveState()` | Void | Persist tabs to UserDefaults |
| `restoreState()` | Void | Restore tabs from UserDefaults |

### State Persistence

Tabs are saved to UserDefaults as JSON:
```json
[
  {"type": "home"},
  {"type": "workspace", "path": "/Users/.../project"},
  {"type": "picker"}
]
```

---

## DashboardViewModel

**File:** `ViewModels/DashboardViewModel.swift`
**Type:** Singleton (`DashboardViewModel.shared`)
**Conforms to:** ObservableObject

**Purpose:** Main data orchestration for projects and stats

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| projects | [Project] | All discovered projects |
| isScanning | Bool | Scan in progress |
| lastScanned | Date? | Last scan time |
| globalActivity | [Date: ActivityStats] | Global activity map |
| todayStats | ActivityStats? | Today's stats |
| weekStats | ActivityStats? | This week's stats |
| monthStats | ActivityStats? | This month's stats |
| allTimeStats | ActivityStats? | All time stats |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `loadDataIfNeeded()` | async | Initial data load |
| `refresh()` | async | Full refresh |
| `syncSingleProject(path: String)` | async | Sync one project |
| `calculateStats()` | Void | Recalculate aggregates |

---

## TerminalTabsViewModel

**File:** `ViewModels/TerminalTabsViewModel.swift`
**Type:** Instance (one per workspace)
**Conforms to:** ObservableObject

**Purpose:** Manages terminal tabs within a workspace

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| tabs | [TerminalTab] | Terminal tabs |
| activeTabID | UUID | Active terminal |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `createTab(kind: TabKind)` | TerminalTab | Create new tab |
| `closeTab(_ id: UUID)` | Void | Close tab |
| `selectTab(_ id: UUID)` | Void | Switch tab |

### Tab Kinds

- `.terminal` — Shell terminal
- `.claude` — Claude Code terminal
- `.devServer` — Dev server output

---

## ProjectListViewModel

**File:** `ViewModels/ProjectListViewModel.swift`
**Type:** Instance
**Conforms to:** ObservableObject

**Purpose:** Project filtering, sorting, and grouping

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| searchText | String | Filter text |
| sortOrder | SortOrder | Current sort |
| showArchived | Bool | Include archived |
| filteredProjects | [Project] | Filtered results |

### Sort Orders

- `.lastActivity` — Most recently active
- `.name` — Alphabetical
- `.lineCount` — Most lines
- `.commitCount` — Most commits

---

## EnvironmentViewModel

**File:** `ViewModels/EnvironmentViewModel.swift`
**Type:** Instance
**Conforms to:** ObservableObject

**Purpose:** Environment variable management for .env files

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| variables | [EnvironmentVariable] | Parsed variables |
| hasChanges | Bool | Unsaved changes |
| isLoading | Bool | Loading state |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `load(from: URL)` | Void | Load .env file |
| `save()` | throws | Save changes |
| `addVariable()` | Void | Add new variable |
| `deleteVariable(_ var: EnvironmentVariable)` | Void | Delete variable |

---

## GitControlsViewModel

**File:** `ViewModels/GitControlsViewModel.swift`
**Type:** Instance
**Conforms to:** ObservableObject

**Purpose:** Git operations (commit, push, branch) UI state

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| currentBranch | String? | Current branch |
| hasChanges | Bool | Uncommitted changes |
| stagedCount | Int | Staged files |
| unstagedCount | Int | Unstaged files |
| untrackedCount | Int | Untracked files |
| isCommitting | Bool | Commit in progress |
| isPushing | Bool | Push in progress |
| commitMessage | String | Commit message input |
| secretsWarnings | [SecretMatch] | Detected secrets |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `refresh()` | async | Refresh git status |
| `stageAll()` | Void | Stage all changes |
| `commit()` | async throws | Create commit |
| `push()` | async throws | Push to remote |
| `createBranch(_ name: String)` | async throws | Create branch |
| `scanForSecrets()` | [SecretMatch] | Scan staged files |

---

## Singleton Pattern

Most ViewModels follow this pattern:

```swift
@MainActor
final class SomeViewModel: ObservableObject {
    static let shared = SomeViewModel()

    @Published var someState: String = ""

    private init() {
        // Private init ensures singleton
    }

    func someMethod() {
        // Business logic
    }
}
```

Usage in views:

```swift
struct SomeView: View {
    @StateObject private var viewModel = SomeViewModel.shared
    // or
    @EnvironmentObject var viewModel: SomeViewModel

    var body: some View {
        Text(viewModel.someState)
            .onAppear { viewModel.someMethod() }
    }
}
```
