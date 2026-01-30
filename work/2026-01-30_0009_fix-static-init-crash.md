# Fix Static Initialization Crash

## Prompt Summary
Fix fatal crash occurring during static initialization. The previous async fix wasn't sufficient because `SettingsViewModel.shared` is initialized during `@main` struct setup - before the run loop exists. Both `SettingsViewModel.init()` and `ProjectStatsApp.init()` were accessing `NSApp` too early.

## Solution
1. **SettingsViewModel.swift:**
   - Emptied `init()` to remove all NSApp access during static initialization
   - Added guard clause to `applyTheme()` for safety
   - Added public `applyThemeIfNeeded()` wrapper method

2. **ProjectStatsApp.swift:**
   - Emptied `init()` to remove NSApp access
   - Moved dock policy and theme application to `.onAppear` on WindowGroup

## Files Modified
- `projectStats/projectStats/ViewModels/SettingsViewModel.swift`
- `projectStats/projectStats/App/ProjectStatsApp.swift`

## Closing Report
- **Change:** Removed all NSApp access from static initialization paths. Theme and dock policy now applied via `.onAppear` when the view hierarchy is ready.
- **Build status:** SUCCESS
- **Self-grade:** A - Comprehensive fix addressing root cause of static init crash while maintaining all functionality.
