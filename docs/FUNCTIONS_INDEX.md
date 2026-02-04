# Functions Index

## Overview

This is a comprehensive index of all public functions in the ProjectStats codebase. Use Cmd+F to search.

**Format:** `ClassName.functionName(parameters) -> ReturnType`

---

## Services

### ProjectScanner

```swift
ProjectScanner.shared.scanProjects(in directory: URL) async -> [Project]
ProjectScanner.shared.scanSingleProject(at path: URL) async -> Project?
```

### GitService

```swift
GitService.shared.isGitRepository(at path: URL) -> Bool
GitService.shared.getRemoteURL(at path: URL) -> String?
GitService.shared.getGitHubURL(at path: URL) -> String?
GitService.shared.getLastCommit(at path: URL) -> Commit?
GitService.shared.getCommitCount(at path: URL, since: Date?) -> Int
GitService.shared.getCommitHistory(at path: URL, limit: Int) -> [Commit]
GitService.shared.getRecentCommitsWithStats(at path: URL, limit: Int) -> [Commit]
GitService.shared.getProjectGitMetrics(at path: URL) -> ProjectGitMetrics
GitService.shared.getLinesChanged(at path: URL, since: Date?) -> (added: Int, removed: Int)
GitService.shared.getLinesChangedFast(at path: URL, since: Date?) -> (added: Int, removed: Int)
GitService.shared.getDailyActivity(at path: URL, days: Int) -> [Date: ActivityStats]
GitService.shared.getCurrentBranch(at path: URL) -> String?
GitService.shared.hasUncommittedChanges(at path: URL) -> Bool
GitService.shared.getFileChanges(at path: URL) -> (staged: Int, unstaged: Int, untracked: Int)
```

### ClaudePlanUsageService

```swift
ClaudePlanUsageService.shared.fetchUsage() async
ClaudePlanUsageService.shared.startHourlyPolling()
ClaudePlanUsageService.shared.stopPolling()
ClaudePlanUsageService.shared.saveSnapshotNow() async
ClaudePlanUsageService.shared.getSnapshots(since date: Date) -> [ClaudePlanUsageSnapshot]
ClaudePlanUsageService.shared.getTodaySnapshots() -> [ClaudePlanUsageSnapshot]
```

### ClaudeUsageService

```swift
ClaudeUsageService.shared.refreshGlobal() async
ClaudeUsageService.shared.refreshProject(_ path: String) async
ClaudeUsageService.shared.onClaudeFinished(projectPath: String?) async
ClaudeUsageService.shared.onTabSwitch(projectPath: String?) async
```

### TerminalOutputMonitor

```swift
TerminalOutputMonitor.shared.processTerminalOutput(_ line: String)
TerminalOutputMonitor.shared.processTerminalChunk(_ chunk: String)
TerminalOutputMonitor.shared.startSession(provider: AIProviderType, model: AIModel, thinkingLevel: ThinkingLevel, projectPath: String?)
TerminalOutputMonitor.shared.endSession(inputTokens: Int, outputTokens: Int, thinkingTokens: Int, cacheReadTokens: Int, cacheWriteTokens: Int, wasSuccessful: Bool, errorMessage: String?)
TerminalOutputMonitor.shared.updateSessionSettings(provider: AIProviderType, model: AIModel, thinkingLevel: ThinkingLevel)
TerminalOutputMonitor.shared.parseAndEndSession(_ output: String)
```

### TimeTrackingService

```swift
TimeTrackingService.shared.startTracking(project: String)
TimeTrackingService.shared.stopTracking()
TimeTrackingService.shared.startAITracking(project: String, aiType: String)
TimeTrackingService.shared.stopAITracking()
TimeTrackingService.shared.getTodayTime(for project: String?) -> Int
TimeTrackingService.shared.getWeekTime(for project: String?) -> Int
```

### AchievementService

```swift
AchievementService.shared.loadUnlocked()
AchievementService.shared.checkAndUnlock(_ achievement: Achievement, projectPath: String?)
AchievementService.shared.checkFirstCommitOfDay(projectPath: String)
AchievementService.shared.checkTimeBasedAchievements(projectPath: String)
AchievementService.shared.checkFridayDeploy(projectPath: String)
AchievementService.shared.checkCommitCountAchievements(projectPath: String)
AchievementService.shared.onGitPushDetected(projectPath: String)
```

### NotificationService

```swift
NotificationService.shared.sendNotification(title: String, message: String, sound: Bool)
NotificationService.shared.sendPushNotification(title: String, message: String) async
```

### SyncEngine

```swift
SyncEngine.shared.performFullSync(context: ModelContext) async throws
SyncEngine.shared.pushLocalChanges(context: ModelContext) async throws
SyncEngine.shared.pullRemoteChanges(context: ModelContext) async throws
```

### CloudKitContainer

```swift
CloudKitContainer.shared.setupZone() async throws
CloudKitContainer.shared.setupSubscription() async throws
```

### OfflineQueueManager

```swift
OfflineQueueManager.shared.queueOperation(_ op: SyncOperation)
OfflineQueueManager.shared.processQueue() async
OfflineQueueManager.shared.startMonitoring()
```

### SyncScheduler

```swift
SyncScheduler.shared.start()
SyncScheduler.shared.stop()
SyncScheduler.shared.syncNow() async
```

### BackupService

```swift
BackupService.shared.createBackup(for path: URL) async throws -> URL
BackupService.shared.revealInFinder(_ url: URL)
```

### BranchService

```swift
BranchService.shared.createLocalBranch(from: URL, branchName: String) async throws -> URL
BranchService.shared.listLocalBranches(for: URL) -> [URL]
BranchService.shared.deleteLocalBranch(_ url: URL) throws
```

### SecretsScanner

```swift
SecretsScanner.scan(file: URL) -> [SecretMatch]
SecretsScanner.scanStagedFiles(in: URL) -> [SecretMatch]
```

### TTSService

```swift
TTSService.shared.speak(_ text: String) async throws
TTSService.shared.stop()
```

### VoiceNoteRecorder

```swift
VoiceNoteRecorder.shared.startRecording()
VoiceNoteRecorder.shared.stopRecording() async -> String?
```

### GitHubService

```swift
GitHubService.shared.fetchNotifications() async
GitHubService.shared.fetchUser() async
GitHubService.shared.markAsRead(_ id: String) async
```

### GitHubClient

```swift
GitHubClient.fetchRepoStats(owner: String, repo: String) async -> GitHubStats?
GitHubClient.testConnection(token: String) async -> Bool
```

### MessagingService

```swift
MessagingService.shared.send(message: String, projectPath: String?) async
MessagingService.shared.startPollingIfNeeded()
```

### LineCounter

```swift
LineCounter.count(at path: URL) -> (lines: Int, files: Int)
```

### KeychainService

```swift
KeychainService.save(key: String, data: Data) -> Bool
KeychainService.load(key: String) -> Data?
KeychainService.delete(key: String) -> Bool
```

### ErrorDetector

```swift
ErrorDetector.detectError(in line: String) -> DetectedError?
```

### DataMigrationService

```swift
DataMigrationService.shared.migrateIfNeeded(modelContext: ModelContext) async
```

### DBv2MigrationService

```swift
DBv2MigrationService.shared.migrateIfNeeded(context: ModelContext) async
```

### DataCleanupService

```swift
DataCleanupService.shared.cleanupIfNeeded(context: ModelContext) async
```

---

## ViewModels

### TabManagerViewModel

```swift
TabManagerViewModel.shared.newTab()
TabManagerViewModel.shared.closeTab(_ id: UUID)
TabManagerViewModel.shared.closeOtherTabs(keeping id: UUID)
TabManagerViewModel.shared.selectTab(_ id: UUID)
TabManagerViewModel.shared.selectTab(at index: Int)
TabManagerViewModel.shared.nextTab()
TabManagerViewModel.shared.previousTab()
TabManagerViewModel.shared.moveTab(from sourceId: UUID, to destinationId: UUID)
TabManagerViewModel.shared.openProject(path: String)
TabManagerViewModel.shared.navigateBack()
TabManagerViewModel.shared.isFavorite(_ tab: AppTab) -> Bool
TabManagerViewModel.shared.toggleFavorite(_ tab: AppTab)
TabManagerViewModel.shared.saveState()
TabManagerViewModel.shared.restoreState()
```

### DashboardViewModel

```swift
DashboardViewModel.shared.loadDataIfNeeded() async
DashboardViewModel.shared.refresh() async
DashboardViewModel.shared.syncSingleProject(path: String) async
DashboardViewModel.shared.calculateStats()
```

### SettingsViewModel

```swift
SettingsViewModel.shared.selectCodeDirectory()
SettingsViewModel.shared.openInTerminal(_ path: URL)
SettingsViewModel.shared.testNotification()
SettingsViewModel.shared.applyThemeIfNeeded()
```

### TerminalTabsViewModel

```swift
terminalTabsVM.createTab(kind: TabKind) -> TerminalTab
terminalTabsVM.closeTab(_ id: UUID)
terminalTabsVM.selectTab(_ id: UUID)
```

### GitControlsViewModel

```swift
gitControlsVM.refresh() async
gitControlsVM.stageAll()
gitControlsVM.commit() async throws
gitControlsVM.push() async throws
gitControlsVM.createBranch(_ name: String) async throws
gitControlsVM.scanForSecrets() -> [SecretMatch]
```

### EnvironmentViewModel

```swift
environmentVM.load(from: URL)
environmentVM.save() throws
environmentVM.addVariable()
environmentVM.deleteVariable(_ var: EnvironmentVariable)
```

---

## Models (Instance Methods)

### CachedProject

```swift
cachedProject.toProject() -> Project
cachedProject.update(from project: Project)
```

### SavedPrompt

```swift
savedPrompt.toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord
savedPrompt.update(from record: CKRecord)
SavedPrompt.from(record: CKRecord) -> SavedPrompt?
```

### SavedDiff

```swift
savedDiff.toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord
SavedDiff.from(record: CKRecord) -> SavedDiff?
```

### AISessionV2

```swift
session.end(inputTokens: Int, outputTokens: Int, thinkingTokens: Int, cacheReadTokens: Int, cacheWriteTokens: Int, wasSuccessful: Bool, errorMessage: String?)
session.toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord
```

### TimeEntry

```swift
timeEntry.toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord
```

### AIModel

```swift
AIModel.calculateCost(inputTokens: Int, outputTokens: Int) -> Double
AIModel.models(for provider: AIProviderType) -> [AIModel]
```

### Commit

```swift
Commit.fromGitLog(_ line: String) -> Commit?
```

---

## Utilities / Extensions

### Shell

```swift
Shell.run(_ command: String, at path: URL?) -> String
```

### Date Extensions

```swift
Date.startOfDay -> Date
Date.relativeString -> String
Date.fromGitDate(_ string: String) -> Date?
```

### String Extensions

```swift
string.sha256 -> String
```

### URL Extensions

```swift
url.isDirectory -> Bool
```

---

## Static Factory Methods

### AppTab

```swift
AppTab.homeTab() -> AppTab
AppTab.newTab() -> AppTab
```

### ProjectStatus

```swift
ProjectStatus.from(jsonStatus: String) -> ProjectStatus
```

---

## Search Tips

1. **Find all methods of a service:** Search for `ServiceName.shared.`
2. **Find async methods:** Search for `async`
3. **Find CloudKit methods:** Search for `CKRecord` or `toCKRecord`
4. **Find computed properties:** Search for `var` + return type
5. **Find singletons:** Search for `.shared`
