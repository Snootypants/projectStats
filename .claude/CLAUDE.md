# ProjectStats

macOS menu bar app for tracking developer coding activity and statistics across all projects. Built with SwiftUI + SwiftData, targeting macOS 14+.

## Architecture
- **SwiftUI** for all UI, **SwiftData** for persistence
- **Service-oriented**: ~40+ singleton services (`static let shared`)
- **MVVM**: ViewModels are `@MainActor` classes with `@Published` properties
- **Shell utility** (`Shell.swift`) for all subprocess/git operations — use `Shell.runResult()`, never raw `Process()`
- Async/await throughout, actor isolation for concurrency

## Directory Layout
- `App/` — entry point, AppDelegate
- `Models/` — SwiftData `@Model` classes + plain data models
- `Services/` — singleton services (GitService, ProjectScanner, LineCounter, etc.)
- `ViewModels/` — `@MainActor` observable view models
- `Views/` — organized by feature (Dashboard, IDE, Git, Settings, etc.)
- `Utilities/` — Shell, extensions
- `Resources/Assets.xcassets` — the asset catalog that's actually compiled (NOT the top-level Assets.xcassets)

## Key Conventions
- Services: `[Feature]Service.swift` with `static let shared`
- Views organized by feature folder under `Views/`
- JSON-first project discovery via `projectstats.json` files
- Bundle ID: `com.calebbelshe.projectStats`
- LSUIElement = YES (menu bar app, no dock icon by default)

## Build
- Xcode project (not SPM), single target
- Dependency: SwiftTerm (terminal emulation)
- Min deployment: macOS 14.0
- GENERATE_INFOPLIST_FILE = YES — use `INFOPLIST_KEY_*` build settings, not a manual plist

## Safety
- CRITICAL: Never use NSWindow level `.screenSaver` — locks out Force Quit. Use `.floating` or `.statusBar` max.
- Never use raw `Process()` — always go through `Shell.runResult()`
