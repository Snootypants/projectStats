# Views

## Overview

| Metric | Count |
|--------|-------|
| Total view files | 62 |
| UI Framework | SwiftUI |
| View folders | 18 |

## View Hierarchy

```
ProjectStatsApp
│
├── WindowGroup("main")
│   └── TabShellView
│       ├── TabBarView (Chrome-style tab strip)
│       │   ├── Home tab (pinned)
│       │   ├── Project tabs (closeable)
│       │   └── + New tab button
│       │
│       ├── XPProgressBar
│       │
│       └── Tab Content
│           ├── HomeView (when tab.content == .home)
│           │   ├── StatsCardsView
│           │   ├── TimeTrackingCard
│           │   ├── ClaudeUsageCard
│           │   ├── ClaudeTokenUsageCard
│           │   ├── GitHubNotificationsCard
│           │   ├── ActivityHeatMap
│           │   └── Recent Projects Grid
│           │
│           ├── ProjectPickerView (when .projectPicker)
│           │   └── ProjectListView (grid of projects)
│           │
│           └── WorkspaceView (when .projectWorkspace)
│               └── IDEModeView
│                   ├── FileBrowserView (left panel)
│                   ├── FileViewerView (center panel)
│                   └── TerminalPanelView (right panel)
│                       ├── TerminalTabBar
│                       ├── TerminalTabView
│                       └── Tool Tabs
│                           ├── PromptManagerView
│                           ├── DiffManagerView
│                           └── EnvironmentManagerView
│
├── MenuBarExtra
│   └── MenuBarView
│       ├── Quick stats
│       ├── Recent projects (QuickProjectRow)
│       └── Settings button
│
├── Settings
│   └── SettingsView (sidebar navigation)
│       ├── General
│       ├── Appearance
│       ├── Notifications
│       ├── AI Providers
│       ├── Claude Usage
│       ├── Messaging
│       ├── Sync
│       ├── Data Management
│       └── Account
│
└── Sheets/Modals
    ├── FocusModeView
    ├── CommandPaletteView
    ├── AchievementsSheet
    ├── ProjectDetailView
    ├── CommitDialog
    ├── CreateBranchSheet
    ├── SecretsWarningSheet
    └── NewProjectWizard
```

---

## Views by Folder

### TabBar/ (5 files)

| View | Purpose |
|------|---------|
| TabShellView.swift | Root container with tab bar, XP bar, and content area |
| TabBarView.swift | Chrome-style horizontal tab strip with drag-reorder |
| HomeView.swift | Home tab dashboard with cards and recent projects |
| ProjectPickerView.swift | New tab landing page with project grid |
| WorkspaceView.swift | Project workspace wrapper around IDEModeView |

---

### Dashboard/ (10 files)

| View | Purpose |
|------|---------|
| DashboardView.swift | Legacy dashboard view (unused, kept for reference) |
| StatsCardsView.swift | Grid of stat cards (today, week, month, all time) |
| TimeTrackingCard.swift | Time tracking with human/AI breakdown and chart |
| ClaudeUsageCard.swift | Plan usage percentage (5h/7d) with reset times |
| ClaudeTokenUsageCard.swift | ccusage token stats and cost display |
| GitHubNotificationsCard.swift | GitHub notifications list with mark-as-read |
| ActivityChart.swift | 7-day bar chart of commits/lines |
| ActivityHeatMap.swift | GitHub-style contribution calendar (365 days) |
| ProviderComparisonCard.swift | AI provider cost comparison table |
| SessionSummaryView.swift | AI session summary display |

---

### IDE/ (13 files)

| View | Purpose |
|------|---------|
| IDEModeView.swift | Main three-panel IDE layout with resizable dividers |
| FileBrowserView.swift | File tree explorer with expand/collapse |
| FileViewerView.swift | Syntax-highlighted code viewer |
| TerminalPanelView.swift | Terminal container with tab bar |
| TerminalTabBar.swift | Terminal tab strip (Terminal, Claude, Dev Server) |
| TerminalTabView.swift | Single SwiftTerm terminal instance |
| PromptManagerView.swift | Prompts tab with list and editor |
| DiffManagerView.swift | Diffs tab with saved patches |
| EnvironmentManagerView.swift | .env file editor |
| EnvironmentVariableRow.swift | Single environment variable row |
| ContextUsageBar.swift | Claude context window usage progress bar |
| DevServerTab.swift | Development server panel |
| RunningServersPopover.swift | Popover listing running dev servers |

---

### MenuBar/ (2 files)

| View | Purpose |
|------|---------|
| MenuBarView.swift | Menu bar popover with stats and recent projects |
| QuickProjectRow.swift | Project row in menu bar with open actions |

---

### Settings/ (12 files)

| View | Purpose |
|------|---------|
| SettingsView.swift | Main settings with sidebar navigation |
| NotificationSettings.swift | Notification preferences toggles |
| MessagingSettings.swift | Telegram/Slack/Discord webhook setup |
| AIProviderSettingsView.swift | AI provider configuration |
| AISettings.swift | AI model and thinking level settings |
| ClaudeUsageSettingsView.swift | ccusage display options |
| SyncSettingsView.swift | iCloud sync settings |
| SyncLogView.swift | Sync operation history log |
| CloudSyncSettings.swift | Custom cloud sync endpoint settings |
| DataManagementView.swift | Data cleanup, export, backup actions |
| AccountView.swift | Account/profile settings |
| SubscriptionView.swift | Pro subscription management |

---

### Projects/ (5 files)

| View | Purpose |
|------|---------|
| ProjectListView.swift | Grid/list view of all projects |
| ProjectRowView.swift | Single project card with stats |
| ProjectDetailView.swift | Full project detail sheet |
| ProjectGroupSheet.swift | Project grouping editor |
| ReadmePreview.swift | README markdown rendering |

---

### Achievements/ (4 files)

| View | Purpose |
|------|---------|
| AchievementsDashboard.swift | Full achievements grid with categories |
| AchievementsSheet.swift | Modal sheet for achievements |
| AchievementBanner.swift | Toast banner when achievement unlocked |
| ShareCardView.swift | Share achievement as image |

---

### Git/ (4 files)

| View | Purpose |
|------|---------|
| GitControlsView.swift | Git toolbar (branch, commit, push buttons) |
| CommitDialog.swift | Git commit message dialog |
| CreateBranchSheet.swift | Branch creation sheet |
| SecretsWarningSheet.swift | Warning when secrets detected in staged files |

---

### FocusMode/ (1 file)

| View | Purpose |
|------|---------|
| FocusModeView.swift | Distraction-free Claude session view with plan usage |

---

### CommandPalette/ (1 file)

| View | Purpose |
|------|---------|
| CommandPaletteView.swift | Cmd+K command palette with fuzzy search |

---

### Components/ (4 files)

| View | Purpose |
|------|---------|
| ModelSelectorView.swift | AI model dropdown selector |
| ListenButton.swift | TTS playback button |
| ProBadge.swift | Pro subscription badge |
| SyncStatusView.swift | Sync status indicator (syncing, error, last sync time) |

---

### Claude/ (1 file)

| View | Purpose |
|------|---------|
| ClaudeConfigSheet.swift | Claude-specific configuration sheet |

---

### Notes/ (2 files)

| View | Purpose |
|------|---------|
| ScratchPadView.swift | Quick notes panel per project |
| VoiceNoteView.swift | Voice recording interface with transcription |

---

### Reports/ (2 files)

| View | Purpose |
|------|---------|
| ReportGeneratorView.swift | Report generation options UI |
| ReportPreviewView.swift | Report preview before export |

---

### Security/ (2 files)

| View | Purpose |
|------|---------|
| SecretsWarningView.swift | Secrets scan results display |
| HygieneReportView.swift | Security hygiene report |

---

### Templates/ (1 file)

| View | Purpose |
|------|---------|
| NewProjectWizard.swift | Create new project wizard |

---

### WorkItems/ (1 file)

| View | Purpose |
|------|---------|
| WorkItemsView.swift | Task/bug tracker view |

---

## Key View Details

### TabShellView

The root view container that manages:
- Tab bar at top
- XP progress bar below tabs
- Tab content switching based on `tabManager.activeTab`
- Keyboard shortcuts (Cmd+Shift+T, Cmd+Shift+W, etc.)
- Focus mode sheet
- Command palette sheet

```swift
struct TabShellView: View {
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            Divider()
            XPProgressBar()
            tabContent(for: tabManager.activeTab)
        }
    }
}
```

### IDEModeView

Three-panel layout with resizable dividers:

```
┌────────────────┬────────────────┬────────────────┐
│                │                │                │
│   File         │    Code        │   Terminal     │
│   Browser      │    Viewer      │   + Tools      │
│                │                │                │
│   (toggleable) │  (toggleable)  │  (toggleable)  │
│                │                │                │
└────────────────┴────────────────┴────────────────┘
```

Panels can be shown/hidden via toolbar toggles. Widths are persisted via @AppStorage.

### ActivityHeatMap

GitHub-style contribution calendar showing 365 days of activity. Each cell is colored based on commit count:

- 0 commits: gray
- 1-2 commits: light green
- 3-5 commits: medium green
- 6+ commits: dark green

### FocusModeView

Distraction-free view during Claude sessions:
- Large Claude status indicator
- Plan usage percentage with progress ring
- Session duration timer
- Minimal UI, dark background
- Escape to exit

### SettingsView

Sidebar navigation with sections:

```swift
enum SettingsSection {
    case general
    case appearance
    case notifications
    case aiProviders
    case claudeUsage
    case messaging
    case sync
    case dataManagement
    case account
}
```

Each section renders its own settings panel.
