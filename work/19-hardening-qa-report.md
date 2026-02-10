# Prompt 19 — Hardening, QA Audit & Architectural Debt Cleanup
## QA Report (Scope J)

**Date:** 2026-02-09
**Codebase:** 191 Swift files, ~31,071 lines
**Commits:** 9 [HARDEN] commits, 63 unique files touched

---

## Scope Results

### A — Crash Audit: Force Unwraps & try! (ba5c394)
- **Before:** 3 `try!` calls, several implicit force unwraps
- **After:** 0 `try!` remaining, all replaced with safe alternatives
- **Files:** 3 changed

### B — DashboardViewModel Decomposition (fffbf30)
- **Before:** 1,247 lines in a single god-object ViewModel
- **After:** 392 lines — orchestration only
- **Extracted:** ProjectSyncService (731 lines), ActivityCalculationService (92 lines), GitHubSyncService (55 lines)
- **Files:** 5 changed (965 insertions, 929 deletions)

### C — @AppStorage Key Registry (9a0f179)
- **Before:** ~120 hardcoded @AppStorage string keys scattered across 20+ files
- **After:** All keys centralized in `AppStorageKeys` enum with categorized namespaces
- **Files:** 21 changed

### D — Structured Logging (e157ead)
- **Before:** print() statements scattered across 27 files
- **After:** All replaced with categorized `Log.*` (lifecycle, data, claude, sync, etc.)
- **Remaining:** 0 stray print() calls (1 is inside a Python template literal)
- **Files:** 27 changed

### E — Shell Timeouts (ad2fd26)
- **Before:** Shell.runResult() had no timeout; git ops could hang forever
- **After:** Configurable timeout (default 30s), git availability pre-check
- **Files:** 1 changed

### F — SwiftData Safety (3807204)
- **Before:** 19 instances of `try? context.save()` silently swallowing errors
- **After:** All 19 replaced with `context.safeSave()` — errors logged with caller info
- **New:** DataBackupService — timestamped backups before migrations, max 5 retained
- **New:** ModelContext+SafeSave extension
- **Files:** 17 changed

### G — Dead Code Audit (ec324f1)
- **Identified:** 3 dead types (ErrorDetector, ClaudeTokenUsageCard, FocusModeWindowManager)
- **Marked:** All tagged with `FIXME: [DEAD CODE]` for future cleanup
- **Also found:** 4 TODOs, 4 FIXMEs, 2 barely-used DB v2 models (WorkItem, WeeklyGoal)
- **Files:** 3 changed

### H — VIBE Memory Safety (f7d861f)
- **Before:** ClaudeProcessManager had no deinit; closures retained after cleanup
- **After:** Added deinit (terminates orphaned processes), cleanup() now nils eventHandler + rawLineHandler
- **VibeChatViewModel:** Already clean — proper [weak self] throughout
- **Files:** 1 changed

### I — Migration Safety (93b105e)
- **Before:** Migration versions scattered across DataMigrationService + DBv2MigrationService with local constants
- **After:** Centralized `SchemaVersion` enum; backup-before-nuke in AppModelContainer
- **New:** SchemaVersion.swift — single source of truth for data versions
- **Files:** 6 changed

---

## Before/After Summary

| Metric | Before | After |
|--------|--------|-------|
| `try!` calls | 3 | 0 |
| `try? context.save()` | 19 | 0 |
| `print()` (stray) | ~135 | 0 |
| DashboardViewModel lines | 1,247 | 392 |
| Hardcoded @AppStorage keys | ~120 | 0 (all in registry) |
| Shell timeout | none | 30s default |
| DataBackupService | none | auto-backup before migrations |
| Process deinit | missing | terminates + cleans up |
| Migration version tracking | scattered | centralized SchemaVersion |
| Dead code markers | 0 | 3 tagged for cleanup |

## Remaining Tech Debt
- 4 TODOs (subscription backend, achievement parsing, project creation UI, function stubs)
- 4 FIXMEs (3 dead code markers + 1 existing)
- WorkItem/WeeklyGoal models in schema but not actively used (DB v2 future)
- ErrorDetector.swift can be deleted entirely
- FocusModeWindowManager.swift can be deleted entirely
