# File Structure

## Overview

| Metric | Count |
|--------|-------|
| Total Swift files | 158 |
| Total lines of code | ~25,500 |
| Models | 21 files |
| Views | 62 files |
| ViewModels | 7 files |
| Services | 47 files |
| Utilities | 6 files |

## Directory Tree

```
projectStats/
├── projectStats.xcodeproj/
│   └── project.pbxproj                    # Xcode project configuration
│
└── projectStats/
    ├── App/
    │   └── ProjectStatsApp.swift          # App entry point, WindowGroup, MenuBarExtra, Settings scene
    │
    ├── Models/
    │   ├── Achievement.swift              # Achievement enum with 22 achievements, AchievementUnlock model
    │   ├── ActivityStats.swift            # Daily activity aggregation struct
    │   ├── AIProvider.swift               # AIProviderType, AIModel, ThinkingLevel enums; AIProviderConfig, AISessionV2 models
    │   ├── AppTab.swift                   # TabContent enum, AppTab struct for tab state
    │   ├── CachedModels.swift             # CachedProject, CachedDailyActivity, CachedPrompt, CachedWorkLog, CachedCommit
    │   ├── ChatMessage.swift              # Chat message model for AI conversations
    │   ├── ClaudePlanUsageSnapshot.swift  # Hourly plan usage snapshot model
    │   ├── ClaudeUsageSnapshot.swift      # Token usage snapshot from ccusage
    │   ├── Commit.swift                   # Git commit struct with parsing
    │   ├── DBv2Models.swift               # ProjectSession, DailyMetric, WorkItem, WeeklyGoal models
    │   ├── EnvironmentVariable.swift      # Environment variable model for .env management
    │   ├── GitRepoInfo.swift              # Git repository metadata struct
    │   ├── Project.swift                  # In-memory Project struct, ProjectStatus enum, GitHubStats
    │   ├── ProjectGroup.swift             # Project grouping model
    │   ├── ProjectNote.swift              # Scratch pad notes model
    │   ├── ProjectTemplate.swift          # Project template for new project wizard
    │   ├── SavedDiff.swift                # Saved diff/patch model with CloudKit mapping
    │   ├── SavedPrompt.swift              # Saved prompt model with CloudKit mapping
    │   ├── SecretMatch.swift              # Secret detection result struct
    │   └── TimeEntry.swift                # Time tracking entry model with CloudKit mapping
    │
    ├── ViewModels/
    │   ├── DashboardViewModel.swift       # Main data orchestration, project scanning, stats
    │   ├── EnvironmentViewModel.swift     # Environment variable management
    │   ├── GitControlsViewModel.swift     # Git operations (commit, push, branch)
    │   ├── ProjectListViewModel.swift     # Project filtering, sorting, grouping
    │   ├── SettingsViewModel.swift        # All @AppStorage settings (60+ keys)
    │   ├── TabManagerViewModel.swift      # Tab state, navigation, persistence
    │   └── TerminalTabsViewModel.swift    # Terminal tab management within workspace
    │
    ├── Views/
    │   ├── Achievements/
    │   │   ├── AchievementBanner.swift    # Toast banner for unlocks
    │   │   ├── AchievementsDashboard.swift # Full achievements grid view
    │   │   ├── AchievementsSheet.swift    # Modal sheet for achievements
    │   │   └── ShareCardView.swift        # Share achievement as image
    │   │
    │   ├── Claude/
    │   │   └── ClaudeConfigSheet.swift    # Claude-specific configuration sheet
    │   │
    │   ├── CommandPalette/
    │   │   └── CommandPaletteView.swift   # Cmd+K command palette
    │   │
    │   ├── Components/
    │   │   ├── ListenButton.swift         # TTS playback button
    │   │   ├── ModelSelectorView.swift    # AI model dropdown selector
    │   │   ├── ProBadge.swift             # Pro subscription badge
    │   │   └── SyncStatusView.swift       # Sync status indicator
    │   │
    │   ├── Dashboard/
    │   │   ├── ActivityChart.swift        # 7-day bar chart
    │   │   ├── ActivityHeatMap.swift      # GitHub-style contribution calendar
    │   │   ├── ClaudeTokenUsageCard.swift # ccusage token stats card
    │   │   ├── ClaudeUsageCard.swift      # Plan usage percentage card
    │   │   ├── DashboardView.swift        # Legacy dashboard (unused)
    │   │   ├── GitHubNotificationsCard.swift # GitHub notifications card
    │   │   ├── ProviderComparisonCard.swift # AI provider cost comparison
    │   │   ├── SessionSummaryView.swift   # AI session summary display
    │   │   ├── StatsCardsView.swift       # Stats cards grid
    │   │   └── TimeTrackingCard.swift     # Time tracking with human/AI split
    │   │
    │   ├── FocusMode/
    │   │   └── FocusModeView.swift        # Distraction-free Claude session view
    │   │
    │   ├── Git/
    │   │   ├── CommitDialog.swift         # Git commit dialog
    │   │   ├── CreateBranchSheet.swift    # Branch creation sheet
    │   │   ├── GitControlsView.swift      # Git toolbar (branch, commit, push)
    │   │   └── SecretsWarningSheet.swift  # Warning when secrets detected
    │   │
    │   ├── IDE/
    │   │   ├── ContextUsageBar.swift      # Claude context % progress bar
    │   │   ├── DevServerTab.swift         # Development server panel
    │   │   ├── DiffManagerView.swift      # Diffs tab panel
    │   │   ├── EnvironmentManagerView.swift # .env file editor
    │   │   ├── EnvironmentVariableRow.swift # Single env var row
    │   │   ├── FileBrowserView.swift      # File tree explorer
    │   │   ├── FileViewerView.swift       # Syntax-highlighted code viewer
    │   │   ├── IDEModeView.swift          # Main three-panel IDE layout
    │   │   ├── PromptManagerView.swift    # Prompts tab panel
    │   │   ├── RunningServersPopover.swift # Running dev servers list
    │   │   ├── TerminalPanelView.swift    # Terminal container panel
    │   │   ├── TerminalTabBar.swift       # Terminal tab strip
    │   │   └── TerminalTabView.swift      # Single terminal instance
    │   │
    │   ├── MenuBar/
    │   │   ├── MenuBarView.swift          # Menu bar popover content
    │   │   └── QuickProjectRow.swift      # Project row in menu bar
    │   │
    │   ├── Notes/
    │   │   ├── ScratchPadView.swift       # Quick notes panel
    │   │   └── VoiceNoteView.swift        # Voice recording interface
    │   │
    │   ├── Projects/
    │   │   ├── ProjectDetailView.swift    # Full project detail sheet
    │   │   ├── ProjectGroupSheet.swift    # Project grouping editor
    │   │   ├── ProjectListView.swift      # Project grid/list view
    │   │   ├── ProjectRowView.swift       # Single project card
    │   │   └── ReadmePreview.swift        # README rendering
    │   │
    │   ├── Reports/
    │   │   ├── ReportGeneratorView.swift  # Report generation UI
    │   │   └── ReportPreviewView.swift    # Report preview
    │   │
    │   ├── Security/
    │   │   ├── HygieneReportView.swift    # Security hygiene report
    │   │   └── SecretsWarningView.swift   # Secrets scan results
    │   │
    │   ├── Settings/
    │   │   ├── AccountView.swift          # Account/profile settings
    │   │   ├── AIProviderSettingsView.swift # AI provider configuration
    │   │   ├── AISettings.swift           # AI settings panel
    │   │   ├── ClaudeUsageSettingsView.swift # ccusage display settings
    │   │   ├── CloudSyncSettings.swift    # Custom cloud sync settings
    │   │   ├── DataManagementView.swift   # Data cleanup, export, backup
    │   │   ├── MessagingSettings.swift    # Telegram/Slack/Discord setup
    │   │   ├── NotificationSettings.swift # Notification preferences
    │   │   ├── SettingsView.swift         # Main settings with sidebar
    │   │   ├── SubscriptionView.swift     # Pro subscription management
    │   │   ├── SyncLogView.swift          # Sync operation history
    │   │   └── SyncSettingsView.swift     # iCloud sync settings
    │   │
    │   ├── TabBar/
    │   │   ├── HomeView.swift             # Home tab dashboard
    │   │   ├── ProjectPickerView.swift    # New tab project picker
    │   │   ├── TabBarView.swift           # Chrome-style tab strip
    │   │   ├── TabShellView.swift         # Root view container
    │   │   └── WorkspaceView.swift        # Project workspace wrapper
    │   │
    │   ├── Templates/
    │   │   └── NewProjectWizard.swift     # Create new project wizard
    │   │
    │   └── WorkItems/
    │       └── WorkItemsView.swift        # Task/bug tracker view
    │
    ├── Services/
    │   ├── Core/
    │   │   ├── AchievementService.swift   # Achievement tracking and unlocking
    │   │   ├── AIProviderRegistry.swift   # AI provider management
    │   │   ├── AIService.swift            # AI API calls (embeddings, chat)
    │   │   ├── BackupService.swift        # Project backup to zip
    │   │   ├── BranchService.swift        # Local branch creation (Codex-style)
    │   │   ├── ClaudeContextMonitor.swift # Context window usage tracking
    │   │   ├── ClaudePlanUsageService.swift # Anthropic OAuth API for plan %
    │   │   ├── ClaudeUsageService.swift   # ccusage CLI wrapper
    │   │   ├── CodeVectorDB.swift         # Code embedding database
    │   │   ├── CodexService.swift         # Codex CLI integration
    │   │   ├── DataCleanupService.swift   # Old data cleanup
    │   │   ├── DataMigrationService.swift # Schema migration
    │   │   ├── DBv2MigrationService.swift # DB v2 schema migration
    │   │   ├── EnvFileService.swift       # .env file parsing
    │   │   ├── ErrorDetector.swift        # Terminal error detection
    │   │   ├── FeatureFlags.swift         # Feature flag management
    │   │   ├── GitHubClient.swift         # GitHub API client
    │   │   ├── GitHubService.swift        # GitHub notifications, user info
    │   │   ├── GitRepoService.swift       # Extended git repo inspection
    │   │   ├── GitService.swift           # Core git operations
    │   │   ├── JSONStatsReader.swift      # projectstats.json parser
    │   │   ├── KeychainService.swift      # Secure credential storage
    │   │   ├── LineCounter.swift          # Source code line counting
    │   │   ├── NotificationService.swift  # Local and push notifications
    │   │   ├── ProjectArchiveService.swift # Project archiving
    │   │   ├── ProjectScanner.swift       # Project discovery
    │   │   ├── PromptImportService.swift  # Import prompts from /prompts/
    │   │   ├── ProviderMetricsService.swift # AI provider performance metrics
    │   │   ├── ReportGenerator.swift      # Markdown report generation
    │   │   ├── SecretsScanner.swift       # Secret detection in code
    │   │   ├── SessionSummaryService.swift # AI session summarization
    │   │   ├── StoreKitManager.swift      # In-app purchases
    │   │   ├── TerminalOutputMonitor.swift # Terminal output parsing
    │   │   ├── ThinkingLevelService.swift # Claude thinking level management
    │   │   ├── TimeTrackingService.swift  # Time tracking (human/AI)
    │   │   ├── TTSService.swift           # Text-to-speech (OpenAI/ElevenLabs)
    │   │   └── VoiceNoteRecorder.swift    # Voice recording with Whisper
    │   │
    │   ├── CloudKit/
    │   │   ├── CloudKitContainer.swift    # Container, zone, subscription setup
    │   │   ├── ConflictResolver.swift     # Sync conflict resolution
    │   │   ├── OfflineQueueManager.swift  # Offline change queue
    │   │   ├── Syncable.swift             # Syncable protocol definition
    │   │   ├── SyncableExtensions.swift   # CKRecord mappings for models
    │   │   ├── SyncEngine.swift           # Core sync push/pull
    │   │   └── SyncScheduler.swift        # Periodic sync scheduling
    │   │
    │   ├── Messaging/
    │   │   ├── CloudSyncService.swift     # Legacy cloud sync (custom server)
    │   │   ├── DiscordProvider.swift      # Discord webhook
    │   │   ├── MessagingService.swift     # Unified messaging interface
    │   │   ├── NtfyProvider.swift         # ntfy.sh provider
    │   │   ├── SlackProvider.swift        # Slack webhook
    │   │   └── TelegramProvider.swift     # Telegram bot
    │   │
    │   └── WebAPI/
    │       └── WebAPIClient.swift         # REST API client foundation
    │
    ├── Utilities/
    │   ├── DateExtensions.swift           # Date formatting and parsing
    │   ├── NotificationNames.swift        # Notification.Name constants
    │   ├── ReadmeParser.swift             # README extraction and rendering
    │   ├── Shell.swift                    # Shell command execution
    │   ├── StringExtensions.swift         # String utilities
    │   └── URLExtensions.swift            # URL/path utilities
    │
    ├── Resources/
    │   └── Assets.xcassets/               # App icons, colors, images
    │
    ├── ContentView.swift                  # Legacy root view (unused)
    ├── Item.swift                         # Legacy item model (unused)
    └── projectStatsApp.swift              # Legacy app entry (duplicate)
```

## File Counts by Directory

| Directory | Files | Purpose |
|-----------|-------|---------|
| App/ | 1 | App entry and configuration |
| Models/ | 21 | Data models (SwiftData + structs) |
| ViewModels/ | 7 | Business logic and state management |
| Views/Achievements/ | 4 | Achievement UI components |
| Views/Claude/ | 1 | Claude-specific UI |
| Views/CommandPalette/ | 1 | Command palette |
| Views/Components/ | 4 | Reusable UI components |
| Views/Dashboard/ | 10 | Dashboard cards and charts |
| Views/FocusMode/ | 1 | Focus mode UI |
| Views/Git/ | 4 | Git operation UI |
| Views/IDE/ | 13 | IDE workspace components |
| Views/MenuBar/ | 2 | Menu bar popover |
| Views/Notes/ | 2 | Notes and voice recording |
| Views/Projects/ | 5 | Project list and detail |
| Views/Reports/ | 2 | Report generation |
| Views/Security/ | 2 | Security scanning UI |
| Views/Settings/ | 12 | Settings panels |
| Views/TabBar/ | 5 | Tab navigation |
| Views/Templates/ | 1 | Project creation |
| Views/WorkItems/ | 1 | Task management |
| Services/ | 47 | Business logic services |
| Services/CloudKit/ | 7 | CloudKit sync |
| Services/Messaging/ | 6 | Messaging providers |
| Services/WebAPI/ | 1 | REST client |
| Utilities/ | 6 | Helper extensions |

## Legacy/Unused Files

These files exist but are no longer used:
- `ContentView.swift` — Original root view, replaced by TabShellView
- `Item.swift` — SwiftData sample item, not used
- `projectStatsApp.swift` — Duplicate of App/ProjectStatsApp.swift
