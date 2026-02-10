# Known Issues

## Overview

This document tracks bugs, issues, and quirks discovered during codebase documentation. These are observations, not fixes — per the documentation-only guidelines.

---

## Critical

None identified.

---

## Major

| Issue | Location | Description | Workaround |
|-------|----------|-------------|------------|
| OAuth token dependency | ClaudePlanUsageService | Plan usage requires Claude Code to be installed and authenticated; no graceful handling if token expires | Reinstall/re-auth Claude Code |
| ccusage timeout | ClaudeUsageService | ccusage can hang on some systems; 10-second timeout may not be sufficient | Manual refresh; increase timeout |

---

## Minor

| Issue | Location | Description |
|-------|----------|-------------|
| Duplicate app entry file | `projectStatsApp.swift` vs `App/ProjectStatsApp.swift` | Two app entry point files exist; only App/ version is used |
| Legacy files | `ContentView.swift`, `Item.swift` | Unused template files from Xcode project creation |
| Legacy DashboardView | `Views/Dashboard/DashboardView.swift` | Original dashboard view, replaced by HomeView but still in codebase |
| Hardcoded ntfy topic | SettingsViewModel | Default topic "projectstats-caleb" should be empty or generic |
| DORMANT: AIService | `Services/AIService.swift` | Superseded by AIProviderRegistry, marked DORMANT |
| DORMANT: ErrorDetector | `Services/ErrorDetector.swift` | Never wired to any UI, marked DORMANT |
| DORMANT: VibeTabView | `Views/Vibe/VibeTabView.swift` | Old VIBE tab view, replaced by VIBE Window system |
| Unused schema models | `Models/DBv2Models.swift` | WorkItem and WeeklyGoal registered in schema but not wired to UI |

---

## UI/UX Issues

| Issue | Location | Description |
|-------|----------|-------------|
| Tab close protection | TabManagerViewModel | Home tab is pinned but no visual indicator that it can't be closed |
| Command palette | CommandPaletteView | Some commands marked "TODO" and don't function |
| Workspace panel persistence | IDEModeView | Panel widths persist but panel visibility doesn't always restore correctly |
| Achievement notification spam | AchievementService | No debouncing if multiple achievements unlock simultaneously |

---

## Performance Issues

| Issue | Location | Description |
|-------|----------|-------------|
| Large repo scanning | ProjectScanner, GitService | Repos with many commits can cause slowdowns during getDailyActivity |
| ccusage subprocess | ClaudeUsageService | Spawning npx process is slow; should cache results more aggressively |
| Terminal memory | TerminalTabView | SwiftTerm scrollback buffer can grow large; no automatic truncation |

---

## Potential Data Issues

| Issue | Location | Description |
|-------|----------|-------------|
| API keys in UserDefaults | SettingsViewModel | OpenAI, ElevenLabs API keys stored in UserDefaults, not Keychain |
| Sync conflict resolution | ConflictResolver | Server-wins strategy may lose local changes in edge cases |
| Achievement progress persistence | AchievementService | nightOwlCount/earlyBirdCount stored in UserDefaults, not synced |

---

## Missing Error Handling

| Location | Description |
|----------|-------------|
| SyncEngine | Network errors during sync not surfaced to user clearly |
| GitService | Shell command failures silently return empty results |
| ClaudePlanUsageService | HTTP errors logged but error state may not clear |

---

## Documentation Gaps Found

| Area | Description |
|------|-------------|
| WorkItem model | WorkItem (task/bug tracking) model exists but no visible UI |
| WeeklyGoal model | WeeklyGoal model exists but appears unused |
| ProjectSession model | ProjectSession model for DB v2 but integration unclear |

---

## Architectural Notes

| Observation | Location | Notes |
|-------------|----------|-------|
| Mixed async patterns | Various services | Some use async/await, some use completion handlers, some use Combine |
| State management | ViewModels | Mix of @Published, @AppStorage, and manual observation |
| CloudKit sync partial | SyncEngine | Only SavedPrompt, SavedDiff, AISessionV2, TimeEntry sync; other models local only |

---

## Browser/Platform Notes

| Note | Description |
|------|-------------|
| macOS 14+ only | App requires Sonoma; no backwards compatibility |
| SwiftData schema changes | Schema migrations may be needed if models change significantly |
| CloudKit entitlements | Requires proper CloudKit entitlements in Xcode for sync to work |

---

## How to Report New Issues

During development, if you find issues:

1. Add to this document under appropriate section
2. Include:
   - File/location where issue exists
   - Clear description of the problem
   - Workaround if known
3. Do not attempt to fix during documentation runs

For actual bug fixes, create a separate prompt/commit.
