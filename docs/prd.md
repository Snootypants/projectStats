PRD

ProjectStats - Product Requirements Document (PRD)
Executive Summary
ProjectStats is a native macOS menu bar application that serves as a personal developer dashboard. It scans a developer's code directory, discovers all projects, displays statistics, integrates with GitHub, and provides quick access to project folders, repos, and stats.
Target User: Solo developers or small teams who work on multiple projects and want visibility into their coding activity across all projects.
Platform: macOS 14.0+ (Sonoma)
Tech Stack: Swift 5.9+, SwiftUI, SwiftData, Charts framework

Problem Statement
Developers working on multiple projects lose track of:
* What projects they have
* When they last worked on something
* How much code they've written
* Where their GitHub repos are
* Overall coding activity patterns
Current solutions require manually checking each project folder, opening GitHub, or using external services that don't integrate with local development.

Solution
A lightweight menu bar app that:
1. Lives in the menu bar - Always accessible, never in the way
2. Auto-discovers projects - Scans ~/Code (configurable) for git repos
3. Shows instant stats - Lines of code, commits, last activity
4. Provides quick actions - Open folder, open in VSCode, copy GitHub URL
5. Visualizes activity - GitHub-style contribution heat map
6. Tracks prompts/work logs - For AI-assisted development workflows

User Stories
Menu Bar (Always Visible)
* As a developer, I want to click a menu bar icon and see my recent projects so I can quickly jump to what I was working on
* As a developer, I want to see today's coding stats at a glance (lines, commits)
* As a developer, I want to copy a GitHub URL with one click so I can share it
Dashboard (Deep Dive)
* As a developer, I want to see a GitHub-style activity heat map so I can visualize my coding patterns
* As a developer, I want to see stats for different time periods (today, week, month, all-time)
* As a developer, I want to search/filter my projects by name or language
* As a developer, I want to see project details including README preview
Project Management
* As a developer, I want projects auto-detected from my code folder
* As a developer, I want to open projects in my preferred editor (VSCode, Xcode, etc.)
* As a developer, I want to see which projects have /prompts folders (AI-assisted projects)
* As a developer, I want to see work logs from /work folders

Features Specification
P0 - Must Have (MVP)
1. Menu Bar Presence
* App icon in macOS menu bar
* Click to open popover
* No Dock icon (menu bar only)
2. Project Discovery
* Scan configurable directory (default: ~/Code)
* Detect projects by: .git folder, package.json, .xcodeproj, Cargo.toml
* Extract: name, GitHub URL, language, line count
* Exclude: node_modules, .git, build folders from counts
3. Menu Bar Popover
* Today's stats (lines changed, commits)
* List of 5 most recent projects
* Quick actions per project:
    * Open in Finder
    * Open in editor
    * Copy GitHub URL
4. Basic Dashboard
* Full project list with search
* Sort by: recent, alphabetical, most active
* Project status badges: Active (7 days), In Progress (30 days), Dormant
5. Settings
* Code directory path
* Default editor selection
* Launch at login toggle
P1 - Should Have
6. Activity Heat Map
* GitHub-style contribution calendar
* Based on local git commit history
* Clickable days showing what was worked on
7. Project Detail View
* README.md preview (parsed markdown)
* Commit history (last 20)
* Line/file count breakdown by language
* /prompts folder listing
* /work folder listing
8. Stats Cards
* Today / This Week / This Month / All Time
* Lines added, lines removed, commits
P2 - Nice to Have
9. GitHub API Integration
* Optional PAT configuration
* Pull stars, forks, open issues
* Contribution calendar from GitHub (vs local git)
10. File Watcher
* Real-time updates when files change
* Background refresh
11. Keyboard Shortcuts
* Global hotkey to open menu bar
* Quick project switching
12. Notifications
* "You haven't committed to X in 3 days"
* Daily coding summary

Technical Architecture
Data Flow
~/Code directory
       ↓
ProjectScanner (discovers projects)
       ↓
GitService (extracts git stats)
       ↓
SwiftData (caches results)
       ↓
ViewModels (transforms for UI)
       ↓
SwiftUI Views
Key Components
Component	Responsibility
ProjectScanner	Discovers projects in code directory
GitService	Runs git commands, parses output
LineCounter	Counts lines of code by language
GitHubClient	Optional GitHub API integration
Shell	Executes shell commands
Data Models
struct Project {
    let path: URL
    let name: String
    let description: String?      // From README
    let githubURL: String?        // From .git/config
    let language: String?         // Detected from files
    let lineCount: Int
    let fileCount: Int
    let promptCount: Int?         // From /prompts folder
    let workLogCount: Int?        // From /work folder
    let lastCommitDate: Date?
    let status: ProjectStatus     // .active, .inProgress, .dormant
}

struct DailyActivity {
    let date: Date
    let linesAdded: Int
    let linesRemoved: Int
    let commits: Int
    let projectsWorkedOn: [String]
}

File Structure
projectStats/
├── projectStats/              # Xcode project (compile target)
│   ├── projectStats.xcodeproj
│   └── projectStats/
│       ├── App/
│       ├── Views/
│       ├── ViewModels/
│       ├── Models/
│       ├── Services/
│       ├── Utilities/
│       └── Resources/
│
├── prompts/                   # AI prompts (outside compile folder)
│   ├── 1.md                   # Initial build prompt
│   └── ...
│
└── work/                      # Work logs (outside compile folder)
    ├── YYYY-MM-DD_description.md
    └── stats/
        └── YYYY-MM-DD_HHMM_<hash>.md
Important: The /prompts and /work folders are kept outside the Xcode project folder intentionally. This keeps documentation separate from compiled code and makes it easy to track AI-assisted development without cluttering the build.

Development Process
The tCC Workflow
This project uses tCC (the Claude Coder) - an AI coding agent running in Claude Code CLI. Here's how it works:
1. Prompt-Driven Development
* Human writes detailed prompts in /prompts/N.md
* tCC reads prompt and executes autonomously
* Work is logged in /work/ folder
2. YOLO Mode
* tCC runs with --dangerously-skip-permissions for speed
* Trusts the agent to make good decisions
* Human reviews output, not every step
3. Test-Driven Development (TDD)
* Write tests BEFORE implementation
* Run tests to verify (red → green → refactor)
* npm run test / swift test must pass before commit
4. Quality Gates
Before every commit:
# For Swift projects:
swift build          # Must compile
swift test           # Must pass

# Check for warnings
xcodebuild -scheme projectStats build 2>&1 | grep -i warning
5. Documentation Requirements
After each work session, tCC creates:
* /work/YYYY-MM-DD_HHMM_description.md - What was done
* /work/stats/YYYY-MM-DD_HHMM_<hash>.md - Commit stats
6. Commit Strategy
* Small, focused commits
* Clear commit messages
* One feature/fix per commit

Success Metrics
MVP Success
* [ ] App runs and appears in menu bar
* [ ] Projects discovered from ~/Code
* [ ] Can open project in Finder/editor
* [ ] Can copy GitHub URL
* [ ] Basic stats display correctly
Full Success
* [ ] Activity heat map renders correctly
* [ ] Project details show README preview
* [ ] Settings persist across launches
* [ ] Scanning is fast (<5 seconds for 50 projects)
* [ ] Memory usage stays low (<100MB)

Risks & Mitigations
Risk	Mitigation
Slow scanning for large codebases	Cache results in SwiftData, incremental updates
Git command failures	Graceful error handling, fallback to file system dates
Memory bloat from caching	Limit cached data, lazy loading
Menu bar popover sizing issues	Fixed size with scroll, test on multiple screen sizes
Future Considerations
* iOS Companion App - View stats on phone (CloudKit sync)
* Team Features - Share stats with team (requires backend)
* AI Integration - Summarize recent work using LLM
* Widgets - macOS desktop widgets for stats
* Multiple Directories - Scan multiple code folders

Appendix: Key Decisions
Why SwiftUI over AppKit?
* Modern, declarative UI
* Better for rapid development
* Built-in Charts framework
* MenuBarExtra is native SwiftUI
Why SwiftData over Core Data?
* Simpler API
* Better Swift integration
* Automatic CloudKit sync (future)
* Newer, actively developed
Why local git over GitHub API?
* Works offline
* No rate limits
* Faster (no network)
* Privacy (no data sent externally)
* GitHub API is optional enhancement
Why /prompts and /work outside compile folder?
* Separation of concerns
* Documentation doesn't affect build
* Easy to track AI development process
* Can be version controlled separately if needed

Handoff Notes
What's Been Started
* tCC has begun initial implementation
* Basic Xcode project structure created
* Some services may be partially implemented
What the New Thread Needs
1. This PRD for context
2. The prompt from /prompts/1.md
3. The zip of current progress
4. Understanding of tCC workflow (above)
Key Files to Check First
* projectStats/projectStats/App/ProjectStatsApp.swift - Entry point
* projectStats/projectStats/Services/ProjectScanner.swift - Core logic
* projectStats/projectStats/Services/GitService.swift - Git integration
Likely Next Steps
1. Verify what's been built compiles
2. Complete any partial implementations
3. Get menu bar popover working
4. Add project scanning
5. Build out dashboard

Last Updated: January 30, 2026 Author: Human + Claude (Opus 4.5)
