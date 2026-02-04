# TODO

## Overview

This document captures TODO comments found in the codebase, unimplemented features, and future ideas.

---

## In-Code TODOs

Search performed: `// TODO` — No explicit TODO comments found in codebase.

---

## Placeholder Implementations

| Location | Description |
|----------|-------------|
| CommandPaletteView | "New Terminal Tab" command has `/* TODO */` |
| CommandPaletteView | "Commit Changes" command has `/* TODO */` |
| SyncEngine.processDiffRecord | Empty implementation (comment: "Similar implementation") |
| SyncEngine.processSessionRecord | Empty implementation (comment: "Similar implementation") |
| SyncEngine.processTimeEntryRecord | Empty implementation (comment: "Similar implementation") |

---

## Unimplemented/Partial Features

### WorkItems System

**Location:** `Models/DBv2Models.swift`, `Views/WorkItems/WorkItemsView.swift`

**Status:** Model exists but feature appears incomplete
- WorkItem model has full schema (task, bug, feature, improvement)
- WorkItemsView exists but may not be wired into navigation
- No visible entry point in main UI

### Weekly Goals

**Location:** `Models/DBv2Models.swift`

**Status:** Model exists, no UI found
- WeeklyGoal model supports goal text, targets, progress
- No settings or views for creating/managing goals

### Project Sessions (DB v2)

**Location:** `Models/DBv2Models.swift`, `Services/DBv2MigrationService.swift`

**Status:** Model exists, integration unclear
- ProjectSession tracks coding sessions with metrics
- DailyMetric for aggregation
- May be partially integrated but not fully utilized

### Code Vector DB

**Location:** `Services/CodeVectorDB.swift`

**Status:** SQLite storage exists, usage unclear
- Stores code embeddings
- AIService has embedding endpoint
- No visible semantic search UI

### Report Generation

**Location:** `Services/ReportGenerator.swift`, `Views/Reports/`

**Status:** Partial implementation
- ReportGenerator service exists
- ReportGeneratorView and ReportPreviewView exist
- May need more work to be production-ready

### Pro Subscription

**Location:** `Services/StoreKitManager.swift`, `Views/Settings/SubscriptionView.swift`

**Status:** Scaffolding exists
- StoreKitManager service exists
- SubscriptionView exists
- Product IDs and entitlements may need configuration

### Hygiene Report

**Location:** `Views/Security/HygieneReportView.swift`

**Status:** View exists, integration unclear
- Security hygiene reporting view
- May need more data sources

---

## Features Mentioned But Not Started

Based on model/service analysis:

| Feature | Notes |
|---------|-------|
| Team collaboration | No multi-user models |
| Cloud backup | Only CloudKit sync, no external backup |
| Custom themes | Only light/dark/system |
| Plugin system | No extension architecture |
| AI conversation history | ChatMessage model exists but feature unclear |

---

## Missing Integrations

| Integration | Notes |
|-------------|-------|
| GitLab API | Only GitHub integrated |
| Bitbucket API | Only GitHub integrated |
| Linear/Jira | No issue tracker integration |
| Raycast | No Raycast extension |

---

## UI Polish Needed

| Area | Notes |
|------|-------|
| Empty states | Many views lack proper empty state UI |
| Loading states | Inconsistent loading indicators |
| Error messages | Many errors only logged to console |
| Onboarding | No first-run tutorial |
| Help system | No in-app help/documentation |

---

## Data/Sync Improvements

| Area | Notes |
|------|-------|
| Full model sync | Only some models sync to CloudKit |
| Conflict UI | No user-facing conflict resolution |
| Sync status detail | SyncLogView exists but could show more detail |
| Export formats | Only Markdown export, could add JSON/CSV |

---

## Performance Optimizations

| Area | Notes |
|------|-------|
| Lazy loading | Large project lists could use pagination |
| Background refresh | Some refreshes block UI |
| Cache warming | Cold start could pre-load common data |
| Image caching | Achievement share cards regenerated each time |

---

## Testing

| Area | Notes |
|------|-------|
| Unit tests | No test files found |
| UI tests | No UI test files found |
| Integration tests | No test coverage for API integrations |

---

## Documentation Debt

| Area | Notes |
|------|-------|
| Code comments | Most files lack doc comments |
| API documentation | No generated API docs |
| User guide | No user-facing documentation |
| Video tutorials | No video content |

---

## Future Ideas

Speculative features that could enhance the app:

1. **Widget Extension** — macOS widget showing daily stats
2. **Menu bar mini-dashboard** — More detailed menu bar view
3. **Shortcuts integration** — Siri Shortcuts for common actions
4. **Watch complication** — Show coding streak on Apple Watch
5. **Timeline view** — Visual timeline of coding activity
6. **AI insights** — Use AI to analyze coding patterns
7. **Goal suggestions** — AI-powered goal recommendations
8. **Social features** — Compare stats with friends (opt-in)
9. **Badge system** — Display badges on GitHub profile
10. **Voice commands** — "Hey Siri, start coding session"

---

## Priority Suggestions

If implementing, suggested priority order:

### High Priority
1. Complete WorkItems feature (task tracking)
2. Add unit tests for core services
3. Improve error handling/display

### Medium Priority
4. Complete CloudKit sync for all models
5. Add GitLab/Bitbucket support
6. Implement Weekly Goals UI

### Low Priority
7. Pro subscription features
8. Code Vector DB search UI
9. Widgets and Shortcuts
