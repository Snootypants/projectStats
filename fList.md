# Scope F: Full Repo Re-Audit Findings

Generated: 2026-02-08

---

## HIGH PRIORITY

### F1. FeatureFlags — 5 always-true flags (0 callers)
- **File:** `Services/FeatureFlags.swift` (19 lines)
- **Issue:** `canUseiCloudSync`, `canUseAIFeatures`, `canUseTerminalTabs`, `canUseAchievements`, `canUseTimeTracking` all return `true` unconditionally and have **zero external callers**.
- **Action:** Delete the 5 dead properties. Keep the 4 StoreKit-gated properties (`canUseCloudSync`, `canShareReports`, `canUseWebDashboard`, `historyDays`).

### F2. BranchService — raw Process() instead of Shell.runResult()
- **File:** `Services/BranchService.swift` (153 lines)
- **Issue:** 2 raw `Process()` calls (lines 45, 77) for rsync and git checkout. Inconsistent with codebase `Shell.run()` pattern.
- **Action:** Replace both with `Shell.runResult()` wrapped in async dispatch.

### F3. BackupService — raw Process() instead of Shell.runResult()
- **File:** `Services/BackupService.swift` (102 lines)
- **Issue:** 1 raw `Process()` call (line 28) for ditto zip. Inconsistent with codebase pattern.
- **Action:** Replace with `Shell.runResult()` wrapped in async dispatch.

### F4. GitRepoService — raw Process() instead of Shell.runResult()
- **File:** `Services/GitRepoService.swift` (156 lines)
- **Issue:** `runGit()` helper (lines 76-107) uses raw `Process()` with manual pipe handling. Inconsistent with codebase pattern.
- **Action:** Replace with `Shell.runResult()`. Keep actor + caching architecture.

---

## MEDIUM PRIORITY

### F5. GitService + GitRepoService — duplicate remote URL parsing
- **Files:** `Services/GitService.swift` (274 lines), `Services/GitRepoService.swift` (156 lines)
- **Issue:** Both parse `git@github.com:` SSH URLs to HTTPS independently. GitService returns full URL string, GitRepoService returns `(owner, repo)` tuple.
- **Action (future):** Extract shared parsing utility or have GitRepoService delegate to GitService.

### F6. DashboardViewModel — god object (1,245 lines)
- **File:** `ViewModels/DashboardViewModel.swift` (1,245 lines, 32 functions, ~58 properties)
- **Issue:** Handles project management, activity stats, streak calculation, data persistence, prompt sync, work log sync, recent commits, project scanning, git coordination, and caching.
- **Action (future):** Extract ActivityStatsViewModel, ProjectSyncViewModel, StatisticsService. Keep DashboardViewModel as coordinator/facade.

### F7. SubscriptionManager vs StoreKitManager — dual subscription systems
- **Files:** `Services/SubscriptionManager.swift` (88 lines), `Services/StoreKitManager.swift` (90 lines)
- **Issue:** SubscriptionManager has hardcoded codes (DEV-2026, PRO-XXXX, BETA-XXXX) that delegate to StoreKitManager.isPro. Two sources of truth.
- **Note:** StoreKit is on the DO NOT TOUCH list.

### F8. DataMigrationService + DBv2MigrationService — two migration systems
- **Files:** `Services/DataMigrationService.swift` (257 lines), `Services/DBv2MigrationService.swift` (149 lines)
- **Issue:** Two independent migration systems with separate version tracking. Could run in wrong order.
- **Note:** SwiftData models are on the DO NOT TOUCH list.

### F9. Messaging providers — 3 of 4 are send-only stubs
- **Files:** `DiscordProvider.swift` (25), `SlackProvider.swift` (25), `NtfyProvider.swift` (23), `TelegramProvider.swift` (108)
- **Issue:** Only Telegram has full bidirectional support. Discord/Slack/Ntfy are send-only with `poll()` returning empty arrays.
- **Action (future):** Complete polling implementations or document as send-only.

### F10. EdgeFXOverlay — monolithic effects file
- **File:** `Views/FocusMode/EdgeFXOverlay.swift` (343 lines)
- **Issue:** Fire, smoke, cube effects + embedded SpriteFactory in one file. Paired with 16-line NSViewRepresentable wrapper.
- **Action (future):** Extract SpriteFactory to utilities, split effects into strategies.

### F11. ProjectDetailView — large single view
- **File:** `Views/Projects/ProjectDetailView.swift` (656 lines)
- **Issue:** Contains commit history, readme panel, project stats all in one struct.
- **Action (future):** Extract to DetailCommitView, DetailReadmeView, DetailStatsView.

---

## LOW PRIORITY

### F12. AIProviderRegistry — unused/redundant registry
- **File:** `Services/AIProviderRegistry.swift` (334 lines)
- **Issue:** Creates 5 default providers on first run but `AIService.swift` uses a separate enum pattern. Two AI provider systems.
- **Action (future):** Determine if registry is actively used. If not, remove. If yes, refactor AIService to use it.

### F13. IDEModeView — complex layout
- **File:** `Views/IDE/IDEModeView.swift` (415 lines)
- **Issue:** 5-pane layout with 20+ computed properties and drag-to-resize dividers.
- **Action (future):** Extract layout calculations and panes to sub-views.

### F14. Color hex duplication
- **Files:** `Views/IDE/IDEModeView.swift`, `Views/Settings/SettingsView.swift`
- **Issue:** Both contain fromHex/toHex color conversion inline.
- **Action (future):** Move to `Utilities/ColorExtensions.swift`.

### F15. VibeTerminalBridge — duplicate output buffering
- **File:** `Services/VibeTerminalBridge.swift` (210 lines)
- **Issue:** claudeBuffer with 300ms debounce duplicates VibeConversationService's 2s debounce.
- **Note:** VIBE system is on the DO NOT TOUCH list.

### F16. ProjectCreationService — Kanban scaffold templates
- **File:** `Services/ProjectCreationService.swift` (466 lines)
- **Issue:** 117 lines of HTML/CSS/JS templates for Kanban swarm test. May be experimental.
- **Action (future):** Audit usage, consider extracting to separate ScaffoldTemplates module.

---

## STATS

| Category | Count |
|----------|-------|
| Services | 48 files, 7,108 LOC |
| ViewModels | 7 files, 2,581 LOC |
| Views | ~60 files, ~11,000 LOC |
| Models | 22 files, ~2,123 LOC |
| Utilities | 9 files, 291 LOC |
| Raw Process() usage | 4 services (BranchService, BackupService, GitRepoService, ClaudeUsageService) |
| God objects (>800 lines) | 1 (DashboardViewModel) |
| Always-true feature flags | 5 (zero callers) |

---

## DO NOT TOUCH (per spec)
IDE terminal views, XP system, Claude usage tracking, Time tracking, SwiftData models, Tab/workspace architecture, ThinkingLevelService, VIBE system, StoreKit integration.
