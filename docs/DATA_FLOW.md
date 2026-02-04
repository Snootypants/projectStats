# Data Flow

## Overview

This document describes how data moves through ProjectStats, from user actions to persistent storage.

---

## Project Discovery Flow

```
┌─────────────────────────────────────┐
│ User sets codeDirectory in Settings │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ DashboardViewModel.loadDataIfNeeded()│
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ ProjectScanner.scanProjects()       │
│ - Enumerate directories             │
│ - Check for .git, package.json, etc │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ For each project:                   │
│ ┌─────────────────────────────────┐ │
│ │ JSONStatsReader.read()          │ │
│ │ (if projectstats.json exists)   │ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ GitService.getLastCommit()      │ │
│ │ GitService.getProjectGitMetrics()│ │
│ └─────────────────────────────────┘ │
│ ┌─────────────────────────────────┐ │
│ │ LineCounter.count()             │ │
│ │ (if no JSON stats)              │ │
│ └─────────────────────────────────┘ │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ Create/Update CachedProject         │
│ in SwiftData                        │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ @Query in Views updates             │
│ automatically via SwiftData         │
└─────────────────────────────────────┘
```

---

## Terminal Output Flow

```
┌─────────────────────────────────────┐
│ User types in TerminalTabView       │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ SwiftTerm processes input           │
│ Sends to PTY                        │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ Terminal output received            │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ TerminalOutputMonitor.processOutput()│
└─────────────────┬───────────────────┘
                  │
        ┌─────────┼─────────┬─────────┐
        │         │         │         │
        ▼         ▼         ▼         ▼
┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐
│Claude     │ │Git Event  │ │Error      │ │Other      │
│Detection  │ │Detection  │ │Detection  │ │Patterns   │
└─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └───────────┘
      │             │             │
      ▼             ▼             ▼
┌───────────┐ ┌───────────┐ ┌───────────┐
│Start/End  │ │Debounce   │ │Update     │
│AISessionV2│ │then sync  │ │lastError  │
│Track time │ │project    │ │           │
│Notify     │ │           │ │           │
└───────────┘ └───────────┘ └───────────┘
```

### Claude Session Detection

```
Terminal output: "╭─" or "⏺ "
        │
        ▼
isClaudeRunning = true
        │
        ├── TimeTrackingService.startAITracking()
        │
        └── Create AISessionV2 in SwiftData

Terminal output: "✻ Cooked for 4m 2s"
        │
        ▼
isClaudeRunning = false
        │
        ├── TimeTrackingService.stopAITracking()
        │
        ├── End AISessionV2 with estimated tokens
        │
        ├── NotificationService.sendNotification() (if enabled)
        │
        └── ClaudeUsageService.onClaudeFinished()
```

---

## CloudKit Sync Flow

```
┌─────────────────────────────────────┐
│ Local change made                   │
│ (SavedPrompt, SavedDiff, etc.)      │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ SwiftData saves to local store      │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ SyncScheduler triggers              │
│ (timer or manual)                   │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ Network online?                     │
└─────────┬───────────────┬───────────┘
          │               │
         Yes              No
          │               │
          ▼               ▼
┌─────────────────┐ ┌─────────────────┐
│SyncEngine       │ │OfflineQueue    │
│.performFullSync()│ │Manager.queue() │
└────────┬────────┘ └─────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐ ┌─────────┐
│Push     │ │Pull     │
│Local    │ │Remote   │
│Changes  │ │Changes  │
└────┬────┘ └────┬────┘
     │           │
     ▼           ▼
┌─────────────────────────────────────┐
│ CKModifyRecordsOperation            │
│ CKFetchRecordZoneChangesOperation   │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ Update serverChangeToken            │
│ Process incoming records            │
│ ConflictResolver if needed          │
└─────────────────────────────────────┘
```

### CKRecord Mapping

```swift
// Model → CKRecord
func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
    let recordID = CKRecord.ID(recordName: "Prompt-\(id)", zoneID: zoneID)
    let record = CKRecord(recordType: "SavedPrompt", recordID: recordID)
    record["id"] = id.uuidString
    record["projectPath"] = projectPath
    record["content"] = content
    return record
}

// CKRecord → Model
static func from(record: CKRecord) -> SavedPrompt? {
    guard let idString = record["id"] as? String,
          let id = UUID(uuidString: idString) else { return nil }
    // ...
}
```

---

## Plan Usage Flow

```
┌─────────────────────────────────────┐
│ App launches                        │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ ClaudePlanUsageService              │
│ .startHourlyPolling()               │
└─────────────────┬───────────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             │             │
┌─────────────┐   │   ┌─────────────┐
│Initial fetch│   │   │Timer fires  │
│on launch    │   │   │every 10 min │
└──────┬──────┘   │   └──────┬──────┘
       │          │          │
       └──────────┼──────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ Read OAuth token from Keychain      │
│ (Claude Code credentials)           │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ GET api.anthropic.com/api/oauth/usage│
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ Parse response                      │
│ Update @Published properties        │
│ - fiveHourUtilization               │
│ - sevenDayUtilization               │
│ - resetsAt times                    │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ If new hour:                        │
│ Save ClaudePlanUsageSnapshot        │
│ to SwiftData                        │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ If usage > 75% and enabled:         │
│ Send notification                   │
└─────────────────────────────────────┘
```

---

## Achievement Flow

```
┌─────────────────────────────────────┐
│ Git push detected in terminal       │
│ (matches "To github.com")           │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ AchievementService                  │
│ .onGitPushDetected(projectPath)     │
└─────────────────┬───────────────────┘
                  │
    ┌─────────────┼─────────────┬─────────────┐
    │             │             │             │
    ▼             ▼             ▼             ▼
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│Check    │ │Check    │ │Check    │ │Check    │
│First    │ │Time     │ │Friday   │ │Commit   │
│Blood    │ │Based    │ │Deploy   │ │Count    │
└────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘
     │           │           │           │
     └───────────┼───────────┼───────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│ checkAndUnlock(achievement)         │
│ - Check if already unlocked         │
│ - Add to unlockedAchievements       │
│ - Insert AchievementUnlock          │
│ - Report to Game Center             │
│ - Send notification (if enabled)    │
└─────────────────────────────────────┘
```

---

## Time Tracking Flow

```
┌─────────────────────────────────────┐
│ User opens project workspace        │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ TimeTrackingService                 │
│ .startTracking(project: path)       │
│ sessionType = "human"               │
└─────────────────┬───────────────────┘
                  │
          ┌───────┴───────┐
          │               │
          ▼               ▼
┌─────────────────┐ ┌─────────────────┐
│Claude detected  │ │User closes tab  │
│                 │ │or switches      │
└────────┬────────┘ └────────┬────────┘
         │                   │
         ▼                   ▼
┌─────────────────┐ ┌─────────────────┐
│startAITracking()│ │stopTracking()   │
│sessionType="ai" │ │Save TimeEntry   │
└────────┬────────┘ └─────────────────┘
         │
         ▼
┌─────────────────┐
│Claude ends      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│stopAITracking() │
│Resume human     │
│tracking         │
└─────────────────┘
```

---

## Settings Flow

```
┌─────────────────────────────────────┐
│ User changes setting in UI          │
│ (e.g., Toggle notification)         │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ @AppStorage property updates        │
│ → UserDefaults writes immediately   │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ @Published triggers view update     │
│ Dependent views re-render           │
└─────────────────────────────────────┘
```

---

## Tab State Flow

```
┌─────────────────────────────────────┐
│ User opens/closes/switches tabs     │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ TabManagerViewModel updates         │
│ - tabs array                        │
│ - activeTabID                       │
└─────────────────┬───────────────────┘
                  │
          ┌───────┴───────┐
          │               │
          ▼               ▼
┌─────────────────┐ ┌─────────────────┐
│View updates     │ │App quits        │
│via @Published   │ │                 │
└─────────────────┘ └────────┬────────┘
                             │
                             ▼
                   ┌─────────────────┐
                   │saveState()      │
                   │→ UserDefaults   │
                   └─────────────────┘

┌─────────────────────────────────────┐
│ App launches                        │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ restoreState()                      │
│ ← UserDefaults                      │
│ Rebuild tabs array                  │
└─────────────────────────────────────┘
```
