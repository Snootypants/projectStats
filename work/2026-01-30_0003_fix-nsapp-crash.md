# Fix NSApp Crash on Launch

## Prompt Summary
Fix fatal crash occurring on app launch due to `NSApp` being nil during `SettingsViewModel` initialization. The crash happened at line 88 in `SettingsViewModel.swift` where `applyTheme()` was called directly from `init()`, but `NSApp` doesn't exist yet during app startup.

## Solution
Wrapped the `applyTheme()` call in `DispatchQueue.main.async` to defer theme application until `NSApp` exists.

## Files Modified
- `projectStats/projectStats/ViewModels/SettingsViewModel.swift`

## Closing Report
- **Change:** Modified `private init()` to defer `applyTheme()` using `DispatchQueue.main.async { [weak self] in self?.applyTheme() }`
- **Lines changed:** 3 lines added, 1 line removed (net +2 lines)
- **Build status:** SUCCESS
- **Self-grade:** A - Minimal, targeted fix that addresses the root cause without modifying any other code or introducing side effects.
