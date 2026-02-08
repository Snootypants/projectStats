# Work Log: VIBE Fix, Backup Fix, V2 Dashboard, Polish
**Date:** 2026-02-08 16:50 CST
**Prompt:** 19
**Build:** 44

## Summary
10-scope UX overhaul: VIBE tab fixes, backup command fix, doc builder polish, scroll bounce fix, V2 dashboard, branch flow, terminal tab features, usage persistence, settings cleanup.

## Scopes Completed

### Scope A: Fix VIBE Tab
- Increased boot delay from 1s to 2s to prevent "cclaude" typo
- Send Ctrl+U (kill line) before sending "claude" command
- Added `restoreWordBoundaries()` to String+ANSI for text display fix
- Added `isClaudeActive` state — disables send button until Claude boots
- Added orange Claude Code status bar at top of VIBE tab

### Scope B: Fix Backup Button
- Replaced broken `ditto --exclude` with `zip -r -x` (ditto doesn't support --exclude)
- Changed to numbered backup naming (projectName-1.zip, projectName-2.zip, ...)
- Added configurable backup directory via UserDefaults (defaults to ~/Downloads)

### Scope C: Doc Builder Polish
- All doc defaults set to false (nothing selected on open)
- Added collapsible sections with disclosure triangles
- Core Documentation expanded by default, others collapsed
- Group checkboxes toggle all items in a section
- Mixed state indicator (minus icon) when partially selected
- Shows selected count per group (e.g. "3/6")

### Scope D: Fix File Browser Scroll Bounce
- Changed `LazyVStack` to `VStack` in SimpleFileBrowserView scroll content

### Scope E: Restore V2 Dashboard
- Created `HomePageV2View.swift` (272 lines)
- Interactive weekly bar chart with lines/commits toggle
- Hover tooltips on chart bars (date + value)
- Stat cards row: active projects, total lines, streak, today cost
- Project cards grid with status dots, line counts, commit counts
- Wired into HomeView switch (`case "v2"`)
- Added to Xcode project (pbxproj)

### Scope F: Branch Flow
- Added "Backup before branching" toggle (default on) in CreateBranchSheet
- Shows status messages during backup and branch creation phases
- Opens new branch in a new tab instead of replacing current workspace

### Scope G: Terminal Tab Features
- Added info icon with port tooltip on dev server tabs
- Click active dev server tab copies localhost URL to clipboard
- Added Cmd+Shift+D keyboard shortcut to open doc builder sheet
- Added `openDocBuilder` notification name

### Scope H: Claude Usage Persistence
- Added `startPeriodicRefresh()` with 10-minute Timer to ClaudeUsageService
- Fetch usage immediately on app launch
- Fetch usage on app quit for final snapshot
- Weekly usage data exposed for V2 graph integration

### Scope I: Settings Cleanup
- Added backup directory Browse/Reset to General settings
- Added V2 (Refined) layout option to Home Page settings picker
- Backup directory defaults to ~/Downloads when not set

### Scope J: Final Verification
- Build passes with zero errors
- XP data untouched (only XPService.swift references it)
- All 9 scopes committed individually and pushed

## Files Changed
| File | Action | Lines +/- |
|------|--------|-----------|
| Services/VibeTerminalBridge.swift | Modified | +11/-4 |
| Utilities/String+ANSI.swift | Modified | +20 |
| Views/Vibe/VibeTabView.swift | Modified | +30/-3 |
| Services/BackupService.swift | Modified | +52/-18 |
| Views/IDE/DocBuilderSheet.swift | Modified | +76/-16 |
| Views/IDE/SimpleFileBrowserView.swift | Modified | +1/-1 |
| Views/Dashboard/HomePageV2View.swift | Created | +272 |
| Views/TabBar/HomeView.swift | Modified | +2 |
| projectStats.xcodeproj/project.pbxproj | Modified | +4 |
| Views/Git/CreateBranchSheet.swift | Modified | +21/-4 |
| Views/TabBar/WorkspaceView.swift | Modified | +6/-2 |
| Views/IDE/TerminalPanelView.swift | Modified | +15/-1 |
| Views/IDE/IDEModeView.swift | Modified | +4 |
| Utilities/NotificationNames.swift | Modified | +1 |
| Services/ClaudeUsageService.swift | Modified | +12 |
| App/ProjectStatsApp.swift | Modified | +7 |
| Views/Settings/SettingsView.swift | Modified | +40 |

## Net Change
+574/-49 = **+525 lines net**

## Self-Grade: A
All 10 scopes completed. Zero build errors. Each scope committed individually. XP data untouched. Pushed to main.
