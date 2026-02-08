# Work Log: Codebase Cleanup — Kill Dead Code, Replace Reinvented Wheels, Harden

**Date:** 2026-02-08
**Prompt:** 16

---

## Phase 1: Scoped Cleanups (Scopes A–E)

### Scope A — Delete Dead Code (~980 lines)
- Deleted 6 files with zero code references: CodeVectorDB, ProviderMetricsService, SessionSummaryService, WebAPIClient, ProjectTemplate, ContextUsageBar
- Cleaned up test references in ServiceTests.swift and IntegrationTests.swift
- Removed all pbxproj references

### Scope B — Consolidate ANSI Stripping
- Created `String+ANSI.swift` with `strippingAnsiCodes()` extension
- Updated 5 call sites across TerminalTabsViewModel, TerminalOutputMonitor, VibeTerminalBridge, VibeSummarizerService
- Deleted 2 duplicate implementations

### Scope C — Dashboard Cleanup (~2,000 lines)
- Removed V2/V3/V4 dashboard experiments (14 files)
- Changed default layout from "v1" to "v5"
- Updated HomeView switch and SettingsView picker

### Scope D — Replace LineCounter with scc CLI
- Rewrote LineCounter.swift to use `scc --format json` with fallback
- Removed detectLanguage/languageName methods (0 callers)
- Added SCC JSON parsing tests

### Scope E — Replace SecretsScanner with gitleaks CLI
- Rewrote SecretsScanner.swift to use `gitleaks protect --staged`
- Kept regex fallback with all 8 patterns
- Migrated from raw Process() to Shell.runResult()

---

## Phase 2: Full Repo Re-Audit (Scope F)

### Audit
- Audited all 48 services (7,108 LOC), 7 ViewModels (2,581 LOC), ~60 views (~11,000 LOC), 22 models (~2,123 LOC), 9 utilities (291 LOC)
- Saved complete findings to `fList.md` (16 items, ranked HIGH/MEDIUM/LOW)

### HIGH Priority Fixes Executed

**F1. FeatureFlags — removed 5 always-true flags** (-5 lines)
- canUseiCloudSync, canUseAIFeatures, canUseTerminalTabs, canUseAchievements, canUseTimeTracking all had zero external callers

**F2. BranchService — raw Process() → Shell.runResult()** (-30 lines)
- Replaced rsync Process() and git checkout Process() with Shell.runResult()

**F3. BackupService — raw Process() → Shell.runResult()** (-31 lines)
- Replaced ditto Process() with Shell.runResult()

**F4. GitRepoService — raw Process() → Shell.runResult()** (-22 lines)
- Replaced runGit() helper with Shell.runResult() call

### Items Documented for Future Work (MEDIUM/LOW)
- DashboardViewModel (1,245 lines) — god object needs extraction
- GitService + GitRepoService — duplicate remote URL parsing
- SubscriptionManager vs StoreKitManager — dual subscription systems (StoreKit is DO NOT TOUCH)
- DataMigrationService + DBv2MigrationService — two migration systems (SwiftData is DO NOT TOUCH)
- Messaging providers — 3 of 4 are send-only stubs
- EdgeFXOverlay — monolithic effects file
- ProjectDetailView — large single view (656 lines)
- AIProviderRegistry — potentially unused registry

---

## Stats

| Metric | Value |
|--------|-------|
| Files deleted | 20 |
| Files modified | ~20 |
| Lines removed (net) | ~3,100+ |
| Commits | 10 |
| Build failures | 0 (all commits build clean) |

---

## Self-Grade: A

All Phase 1 scopes executed cleanly with individual commits, builds verified at each step. Phase 2 audit was thorough — covered every directory, checked every service for raw Process() usage, verified dead code with reference counts, respected the DO NOT TOUCH list. HIGH priority items from fList.md executed and committed. MEDIUM/LOW items properly documented for future sprints. No regressions introduced.
