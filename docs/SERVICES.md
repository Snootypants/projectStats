# Services

## Overview

Services are singleton classes that handle business logic, external integrations, and data operations. Most are marked `@MainActor` and accessed via `ServiceName.shared`.

**Total Services:** 47 files

---

## Core Services

### ProjectScanner

**File:** `Services/ProjectScanner.swift`
**Type:** Singleton (`ProjectScanner.shared`)

**Purpose:** Discovers and scans code projects in the configured directory

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `scanProjects(in: URL)` | async [Project] | Scan directory for projects |
| `scanSingleProject(at: URL)` | async Project? | Scan single project |

---

### GitService

**File:** `Services/GitService.swift`
**Type:** Singleton (`GitService.shared`)

**Purpose:** Core git operations

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `isGitRepository(at: URL)` | Bool | Check if path is git repo |
| `getRemoteURL(at: URL)` | String? | Get remote origin URL |
| `getGitHubURL(at: URL)` | String? | Convert remote to GitHub URL |
| `getLastCommit(at: URL)` | Commit? | Get most recent commit |
| `getCommitCount(at: URL, since: Date?)` | Int | Count commits |
| `getCommitHistory(at: URL, limit: Int)` | [Commit] | Get commit list |
| `getRecentCommitsWithStats(at: URL, limit: Int)` | [Commit] | Commits with line stats |
| `getProjectGitMetrics(at: URL)` | ProjectGitMetrics | 7d/30d metrics |
| `getLinesChanged(at: URL, since: Date?)` | (Int, Int) | Lines added/removed |
| `getLinesChangedFast(at: URL, since: Date?)` | (Int, Int) | Fast line counting |
| `getDailyActivity(at: URL, days: Int)` | [Date: ActivityStats] | Daily activity map |
| `getCurrentBranch(at: URL)` | String? | Current branch name |
| `hasUncommittedChanges(at: URL)` | Bool | Check for changes |
| `getFileChanges(at: URL)` | (Int, Int, Int) | Staged/unstaged/untracked |

---

### ClaudePlanUsageService

**File:** `Services/ClaudePlanUsageService.swift`
**Type:** Singleton (`ClaudePlanUsageService.shared`)
**Conforms to:** ObservableObject

**Purpose:** Fetches Claude plan usage from Anthropic OAuth API

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| fiveHourUtilization | Double | 5h window usage (0-1) |
| fiveHourResetsAt | Date? | 5h reset time |
| sevenDayUtilization | Double | 7d window usage (0-1) |
| sevenDayResetsAt | Date? | 7d reset time |
| opusUtilization | Double? | Opus-specific usage |
| sonnetUtilization | Double? | Sonnet-specific usage |
| lastUpdated | Date? | Last fetch time |
| isLoading | Bool | Loading state |
| error | String? | Error message |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `fetchUsage()` | async | Fetch usage from API |
| `startHourlyPolling()` | Void | Start 10-minute polling |
| `stopPolling()` | Void | Stop polling |
| `saveSnapshotNow()` | async | Save current usage to SwiftData |
| `getSnapshots(since: Date)` | [ClaudePlanUsageSnapshot] | Get historical snapshots |
| `getTodaySnapshots()` | [ClaudePlanUsageSnapshot] | Today's snapshots |

**API Details:**
- Endpoint: `https://api.anthropic.com/api/oauth/usage`
- Auth: Bearer token from Claude Code keychain
- Polling: Every 10 minutes
- Snapshots: Saved hourly to SwiftData

---

### ClaudeUsageService

**File:** `Services/ClaudeUsageService.swift`
**Type:** Singleton (`ClaudeUsageService.shared`)
**Conforms to:** ObservableObject

**Purpose:** Fetches token usage via ccusage CLI

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| globalUsage | UsageData? | Global usage stats |
| projectUsage | UsageData? | Project-specific usage |
| isLoading | Bool | Loading state |
| error | String? | Error message |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `refreshGlobal()` | async | Refresh global stats |
| `refreshProject(_ path: String)` | async | Refresh project stats |
| `onClaudeFinished(projectPath: String?)` | async | Called when Claude session ends |
| `onTabSwitch(projectPath: String?)` | async | Called on tab switch |

**CLI Command:**
```bash
npx ccusage@latest daily --json --since YYYYMMDD
```

---

### TerminalOutputMonitor

**File:** `Services/TerminalOutputMonitor.swift`
**Type:** Singleton (`TerminalOutputMonitor.shared`)
**Conforms to:** ObservableObject

**Purpose:** Monitors terminal output for Claude sessions, git events, errors

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| lastDetectedError | DetectedError? | Most recent error |
| isClaudeRunning | Bool | Claude session active |
| activeSession | AISessionV2? | Current AI session |

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| activeProjectPath | String? | Current project path |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `processTerminalOutput(_ line: String)` | Void | Process single line |
| `processTerminalChunk(_ chunk: String)` | Void | Process multi-line chunk |
| `startSession(provider:model:thinkingLevel:projectPath:)` | Void | Start AI session |
| `endSession(inputTokens:outputTokens:...)` | Void | End AI session |
| `updateSessionSettings(provider:model:thinkingLevel:)` | Void | Update session config |
| `parseAndEndSession(_ output: String)` | Void | Parse tokens and end |

**Detection Patterns:**
- Claude start: `╭─`, `⏺ `, `Claude: `
- Claude end: `✻ Cooked for`, `✻ Crunched for`
- Git events: `[main `, `To github.com`, `git commit`, `git push`

---

### TimeTrackingService

**File:** `Services/TimeTrackingService.swift`
**Type:** Singleton (`TimeTrackingService.shared`)
**Conforms to:** ObservableObject

**Purpose:** Tracks human vs AI coding time

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| currentProjectPath | String? | Active project |
| isTracking | Bool | Tracking active |
| sessionType | String | "human" or "ai" |
| sessionStartTime | Date? | Session start |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `startTracking(project: String)` | Void | Start human tracking |
| `stopTracking()` | Void | Stop tracking |
| `startAITracking(project: String, aiType: String)` | Void | Start AI tracking |
| `stopAITracking()` | Void | Stop AI tracking |
| `getTodayTime(for project: String?)` | Int | Minutes today |
| `getWeekTime(for project: String?)` | Int | Minutes this week |

---

### AchievementService

**File:** `Services/AchievementService.swift`
**Type:** Singleton (`AchievementService.shared`)
**Conforms to:** ObservableObject

**Purpose:** Tracks and unlocks achievements

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| unlockedAchievements | Set<Achievement> | All unlocked |
| recentlyUnlocked | Achievement? | Most recent unlock |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `loadUnlocked()` | Void | Load from SwiftData |
| `checkAndUnlock(_ achievement: Achievement, projectPath: String?)` | Void | Check and unlock |
| `checkFirstCommitOfDay(projectPath: String)` | Void | Check first blood |
| `checkTimeBasedAchievements(projectPath: String)` | Void | Check night owl/early bird |
| `checkFridayDeploy(projectPath: String)` | Void | Check shipper |
| `checkCommitCountAchievements(projectPath: String)` | Void | Check prolific/centurion |
| `onGitPushDetected(projectPath: String)` | Void | Run all checks |

---

### NotificationService

**File:** `Services/NotificationService.swift`
**Type:** Singleton (`NotificationService.shared`)
**Conforms to:** ObservableObject, UNUserNotificationCenterDelegate

**Purpose:** Local and push notifications

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `sendNotification(title: String, message: String, sound: Bool)` | Void | Send local notification |
| `sendPushNotification(title: String, message: String)` | async | Send via ntfy.sh |

**Integration:**
- Local: UNUserNotificationCenter
- Push: ntfy.sh POST to configured topic

---

## CloudKit Services

### SyncEngine

**File:** `Services/CloudKit/SyncEngine.swift`
**Type:** Singleton (`SyncEngine.shared`)
**Conforms to:** ObservableObject

**Purpose:** Core CloudKit sync operations

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| isSyncing | Bool | Sync in progress |
| lastSyncDate | Date? | Last successful sync |
| syncError | Error? | Last error |
| pendingChangesCount | Int | Pending changes |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `performFullSync(context: ModelContext)` | async throws | Full push/pull sync |
| `pushLocalChanges(context: ModelContext)` | async throws | Push to CloudKit |
| `pullRemoteChanges(context: ModelContext)` | async throws | Pull from CloudKit |

**Synced Types:**
- SavedPrompt
- SavedDiff
- AISessionV2
- TimeEntry

---

### CloudKitContainer

**File:** `Services/CloudKit/CloudKitContainer.swift`
**Type:** Singleton (`CloudKitContainer.shared`)

**Purpose:** CloudKit container setup

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| container | CKContainer | CloudKit container |
| privateDatabase | CKDatabase | Private database |
| customZoneID | CKRecordZone.ID | Custom zone ID |
| isSignedIn | Bool | iCloud signed in |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `setupZone()` | async throws | Create custom zone |
| `setupSubscription()` | async throws | Setup push subscription |

---

### OfflineQueueManager

**File:** `Services/CloudKit/OfflineQueueManager.swift`
**Type:** Singleton (`OfflineQueueManager.shared`)
**Conforms to:** ObservableObject

**Purpose:** Queue changes when offline

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| pendingOperations | [SyncOperation] | Queued operations |
| isOnline | Bool | Network status |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `queueOperation(_ op: SyncOperation)` | Void | Add to queue |
| `processQueue()` | async | Process pending |
| `startMonitoring()` | Void | Start network monitor |

---

### SyncScheduler

**File:** `Services/CloudKit/SyncScheduler.swift`
**Type:** Singleton (`SyncScheduler.shared`)
**Conforms to:** ObservableObject

**Purpose:** Schedule periodic syncs

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| isEnabled | Bool | Scheduling enabled |
| intervalMinutes | Int | Sync interval |
| lastSyncTime | Date? | Last sync |
| nextSyncTime | Date? | Next scheduled |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `start()` | Void | Start scheduler |
| `stop()` | Void | Stop scheduler |
| `syncNow()` | async | Trigger immediate sync |

---

### ConflictResolver

**File:** `Services/CloudKit/ConflictResolver.swift`

**Purpose:** Resolve sync conflicts

**Strategy:** Server wins (most recent change preserved)

---

## Integration Services

### GitHubService

**File:** `Services/GitHubService.swift`
**Type:** Singleton (`GitHubService.shared`)
**Conforms to:** ObservableObject

**Purpose:** GitHub API integration

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| notifications | [GitHubNotification] | Unread notifications |
| user | GitHubUser? | Authenticated user |
| isLoading | Bool | Loading state |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `fetchNotifications()` | async | Fetch notifications |
| `fetchUser()` | async | Fetch user info |
| `markAsRead(_ id: String)` | async | Mark notification read |

---

### GitHubClient

**File:** `Services/GitHubClient.swift`

**Purpose:** Low-level GitHub API client

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `fetchRepoStats(owner: String, repo: String)` | async GitHubStats? | Fetch repo stats |
| `testConnection(token: String)` | async Bool | Test token validity |

---

### MessagingService

**File:** `Services/MessagingService.swift`
**Type:** Singleton (`MessagingService.shared`)
**Conforms to:** ObservableObject

**Purpose:** Unified messaging interface

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `send(message: String, projectPath: String?)` | async | Send via configured provider |
| `startPollingIfNeeded()` | Void | Start remote command polling |

**Providers:**
- TelegramProvider
- SlackProvider
- DiscordProvider
- NtfyProvider

---

### CodexService

**File:** `Services/CodexService.swift`
**Type:** Singleton (`CodexService.shared`)

**Purpose:** Codex CLI integration

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `isInstalled()` | Bool | Check if codex CLI available |
| `run(prompt: String, at: URL)` | async String | Run codex command |

---

## Utility Services

### BackupService

**File:** `Services/BackupService.swift`
**Type:** Singleton (`BackupService.shared`)

**Purpose:** Project backup to zip

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `createBackup(for: URL)` | async throws URL | Create zip backup |
| `revealInFinder(_ url: URL)` | Void | Show in Finder |

---

### SecretsScanner

**File:** `Services/SecretsScanner.swift`

**Purpose:** Detect secrets in code

**Static Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `scan(file: URL)` | [SecretMatch] | Scan single file |
| `scanStagedFiles(in: URL)` | [SecretMatch] | Scan git staged files |

**Detects:**
- API keys (AWS, OpenAI, Anthropic, etc.)
- Private keys (RSA, SSH)
- Tokens (JWT, OAuth)
- Passwords in config files

---

### BranchService

**File:** `Services/BranchService.swift`
**Type:** Singleton (`BranchService.shared`)

**Purpose:** Local branch creation (Codex-style: copy folder + git branch)

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `createLocalBranch(from: URL, branchName: String)` | async throws URL | Create branch copy |
| `listLocalBranches(for: URL)` | [URL] | List branch copies |
| `deleteLocalBranch(_ url: URL)` | throws | Delete branch copy |

---

### TTSService

**File:** `Services/TTSService.swift`
**Type:** Singleton (`TTSService.shared`)

**Purpose:** Text-to-speech via OpenAI or ElevenLabs

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `speak(_ text: String)` | async throws | Convert and play |
| `stop()` | Void | Stop playback |

---

### VoiceNoteRecorder

**File:** `Services/VoiceNoteRecorder.swift`
**Type:** Singleton (`VoiceNoteRecorder.shared`)
**Conforms to:** ObservableObject

**Purpose:** Voice recording with Whisper transcription

**Published Properties:**
| Property | Type | Description |
|----------|------|-------------|
| isRecording | Bool | Recording active |
| transcription | String? | Transcribed text |

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `startRecording()` | Void | Start recording |
| `stopRecording()` | async String? | Stop and transcribe |

---

### KeychainService

**File:** `Services/KeychainService.swift`

**Purpose:** Secure credential storage

**Static Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `save(key: String, data: Data)` | Bool | Save to keychain |
| `load(key: String)` | Data? | Load from keychain |
| `delete(key: String)` | Bool | Delete from keychain |

---

### LineCounter

**File:** `Services/LineCounter.swift`

**Purpose:** Count source code lines

**Static Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `count(at: URL)` | (lines: Int, files: Int) | Count lines in project |

**Supported Extensions:**
Web, Backend, Systems, Data/Config, Scripts, Docs (see FILE_STRUCTURE.md)

---

### ErrorDetector

**File:** `Services/ErrorDetector.swift`

**Purpose:** Detect errors in terminal output

**Public Methods:**
| Method | Returns | Description |
|--------|---------|-------------|
| `detectError(in: String)` | DetectedError? | Parse error from line |

---

### FeatureFlags

**File:** `Services/FeatureFlags.swift`
**Type:** Singleton (`FeatureFlags.shared`)
**Conforms to:** ObservableObject

**Purpose:** Feature flag management

---

### StoreKitManager

**File:** `Services/StoreKitManager.swift`
**Type:** Singleton (`StoreKitManager.shared`)
**Conforms to:** ObservableObject

**Purpose:** In-app purchase management

---

### AIProviderRegistry

**File:** `Services/AIProviderRegistry.swift`
**Type:** Singleton (`AIProviderRegistry.shared`)
**Conforms to:** ObservableObject

**Purpose:** Manage multiple AI provider configurations

---

### ProviderMetricsService

**File:** `Services/ProviderMetricsService.swift`
**Type:** Singleton (`ProviderMetricsService.shared`)

**Purpose:** Track AI provider performance metrics

---

### ThinkingLevelService

**File:** `Services/ThinkingLevelService.swift`
**Type:** Singleton (`ThinkingLevelService.shared`)

**Purpose:** Claude thinking level management

---

### SessionSummaryService

**File:** `Services/SessionSummaryService.swift`

**Purpose:** Generate AI session summaries

---

### ReportGenerator

**File:** `Services/ReportGenerator.swift`

**Purpose:** Generate Markdown reports

---

### ClaudeContextMonitor

**File:** `Services/ClaudeContextMonitor.swift`
**Type:** Singleton (`ClaudeContextMonitor.shared`)
**Conforms to:** ObservableObject

**Purpose:** Monitor Claude context window usage

---

### DataMigrationService

**File:** `Services/DataMigrationService.swift`
**Type:** Singleton (`DataMigrationService.shared`)

**Purpose:** Schema migrations

---

### DBv2MigrationService

**File:** `Services/DBv2MigrationService.swift`
**Type:** Singleton (`DBv2MigrationService.shared`)

**Purpose:** DB v2 schema migration

---

### DataCleanupService

**File:** `Services/DataCleanupService.swift`
**Type:** Singleton (`DataCleanupService.shared`)

**Purpose:** Clean up old/orphaned data

---

### PromptImportService

**File:** `Services/PromptImportService.swift`

**Purpose:** Import prompts from /prompts/ directory

---

### EnvFileService

**File:** `Services/EnvFileService.swift`

**Purpose:** Parse and manage .env files

---

### JSONStatsReader

**File:** `Services/JSONStatsReader.swift`

**Purpose:** Parse projectstats.json files

---

### CodeVectorDB

**File:** `Services/CodeVectorDB.swift`

**Purpose:** Code embedding storage with SQLite

---

### AIService

**File:** `Services/AIService.swift`

**Purpose:** AI API calls (embeddings, chat)

---

### ProjectArchiveService

**File:** `Services/ProjectArchiveService.swift`

**Purpose:** Archive/unarchive projects

---

### GitRepoService

**File:** `Services/GitRepoService.swift`

**Purpose:** Extended git repository inspection
