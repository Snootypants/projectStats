Description 

Oh hell yes. A dev dashboard/portfolio tracker Mac app. Let me spec this out:

CodePulse (or whatever you want to call it)
A macOS Developer Dashboard & Project Manager
Core Concept
A native Swift app that lives in your menu bar and gives you instant access to all your projects, their stats, GitHub connections, and a beautiful overview of your coding activity.

Features Breakdown
1. Menu Bar Icon (Always There)
┌─────────────────────────────────────────┐
│ 🔥 CodePulse                      [12] │  ← 12 active projects
├─────────────────────────────────────────┤
│ ⭐ Recent Projects                      │
│   📁 andersonFlightServicesV1    → 📋  │  ← Click folder, flyout copies GitHub URL
│   📁 roguelike-dungeon           → 📋  │
│   📁 plex-automation             → 📋  │
├─────────────────────────────────────────┤
│ 📊 Today: 847 lines │ 3 commits        │
│ 🔥 Streak: 12 days                     │
├─────────────────────────────────────────┤
│ [Open Dashboard]  [Settings]           │
└─────────────────────────────────────────┘
Quick Actions:
* Click project → Opens folder in Finder/VSCode/Terminal
* Hover → Shows last commit, lines changed
* → button → Copies GitHub URL to clipboard
* Keyboard shortcut to open (e.g., ⌘⇧P)

2. Main Dashboard Window
┌─────────────────────────────────────────────────────────────────────────┐
│ CodePulse                                              [−] [□] [×]      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  📊 ACTIVITY OVERVIEW                                     Jan 2026      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Mon  Tue  Wed  Thu  Fri  Sat  Sun                              │   │
│  │  ░░░  ███  ███  ███  ░░░  ██░  ███  ← GitHub-style heat map    │   │
│  │  ░██  ███  ██░  ███  ███  ░░░  ███                              │   │
│  │  ...                                                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  THIS WEEK                          THIS MONTH                          │
│  ┌──────────────────┐               ┌──────────────────┐               │
│  │ 2,847 lines      │               │ 12,450 lines     │               │
│  │ 23 commits       │               │ 89 commits       │               │
│  │ 4 projects       │               │ 7 projects       │               │
│  └──────────────────┘               └──────────────────┘               │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  📁 PROJECTS                                    [Sort: Recent ▼] [🔍]  │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ ┌─────┐                                                         │   │
│  │ │ AFS │ Anderson Flight Services              ⭐ Active         │   │
│  │ └─────┘ Private aviation ops platform                           │   │
│  │         🔗 github.com/caleb/afs  │ 40k lines │ 55 prompts       │   │
│  │         Last: "Add AI admin dashboard" - 2 hours ago            │   │
│  │         [Open] [GitHub] [Copy URL] [Terminal]                   │   │
│  │─────────────────────────────────────────────────────────────────│   │
│  │ ┌─────┐                                                         │   │
│  │ │ 🎮  │ Roguelike Dungeon Crawler             ⚡ In Progress    │   │
│  │ └─────┘ Phaser 3 2D dungeon crawler                             │   │
│  │         🔗 github.com/caleb/roguelike │ 3.2k lines │ 8 prompts  │   │
│  │         Last: "Add enemy AI pathfinding" - 3 days ago           │   │
│  │         [Open] [GitHub] [Copy URL] [Terminal]                   │   │
│  │─────────────────────────────────────────────────────────────────│   │
│  │ ┌─────┐                                                         │   │
│  │ │ 🎬  │ Plex Automation                       💤 Dormant        │   │
│  │ └─────┘ Media server automation scripts                         │   │
│  │         🔗 github.com/caleb/plex-auto │ 1.1k lines              │   │
│  │         Last: "Fix arr stack config" - 2 weeks ago              │   │
│  │         [Open] [GitHub] [Copy URL] [Terminal]                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

3. Project Detail View
When you click a project:
┌─────────────────────────────────────────────────────────────────────────┐
│ ← Back                    Anderson Flight Services                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  📝 README.md                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ # Anderson Flight Services                                      │   │
│  │ Multi-tenant financial intelligence platform for private        │   │
│  │ aviation. Integrates ForeFlight + Expensify to calculate        │   │
│  │ real cost-per-hour for aircraft operations.                     │   │
│  │ ...                                                             │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  📊 STATS                                                               │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐          │
│  │   40,123   │ │    256     │ │     55     │ │    6 days  │          │
│  │   lines    │ │   files    │ │  prompts   │ │  active    │          │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘          │
│                                                                         │
│  📈 COMMIT ACTIVITY (Last 30 days)                                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │     █                                                           │   │
│  │     █   █                    █                                  │   │
│  │  █  █   █  █     █  █        █  █  █                           │   │
│  │  █  █   █  █  █  █  █  █     █  █  █  █                        │   │
│  │  ─────────────────────────────────────────────────────────────  │   │
│  │  Jan 1                              Jan 15                 Jan 29│   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  📋 PROMPTS (/prompts folder)                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ 1.md  - Initial setup, Prisma, auth                             │   │
│  │ 2.md  - RBAC and permissions                                    │   │
│  │ ...                                                             │   │
│  │ 13.md - Daily AI reports, test catch-up                         │   │
│  │                                                    [View All →]  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  📝 WORK LOG (/work folder)                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ 2026-01-29 - user-prefs-audit-ai.md                             │   │
│  │ 2026-01-28 - premium-flight-map.md                              │   │
│  │ 2026-01-28 - action-required-hub.md                             │   │
│  │ ...                                               [View All →]  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  [Open Folder] [Open in VSCode] [Open Terminal] [View on GitHub]       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

4. Data Sources
Local Scanning (/Code folder):
struct ProjectScanner {
    let codeDirectory: URL // ~/Code
    
    func scanProjects() -> [Project] {
        // For each folder in /Code:
        // 1. Check for .git folder → extract remote URL
        // 2. Parse README.md → title, description
        // 3. Count lines of code (*.ts, *.tsx, *.swift, etc.)
        // 4. Check for /prompts folder → count prompts
        // 5. Check for /work folder → parse work logs
        // 6. Get last modified date
    }
}
GitHub API Integration:
struct GitHubClient {
    func getRepoStats(owner: String, repo: String) async -> RepoStats {
        // GET /repos/{owner}/{repo}
        // - stars, forks, watchers
        // - open issues, PRs
        // - last commit info
    }
    
    func getCommitHistory(owner: String, repo: String, since: Date) async -> [Commit] {
        // GET /repos/{owner}/{repo}/commits
        // - commit messages
        // - additions/deletions
        // - author, date
    }
    
    func getContributionCalendar() async -> ContributionData {
        // GraphQL query for contribution calendar
        // - daily commit counts
        // - streak info
    }
}
Git Local Stats:
struct GitLocalStats {
    func getCommitCount(path: URL, since: Date) -> Int {
        // git rev-list --count --since="date" HEAD
    }
    
    func getLinesChanged(path: URL, since: Date) -> (added: Int, removed: Int) {
        // git log --since="date" --numstat
    }
    
    func getLastCommit(path: URL) -> Commit {
        // git log -1 --format="%H|%s|%ai"
    }
}

5. Project Detection Logic
struct Project {
    let path: URL
    let name: String
    let description: String?      // From README
    let githubURL: String?        // From .git/config
    let language: Language        // Detect from files
    let lineCount: Int
    let fileCount: Int
    let promptCount: Int?         // From /prompts
    let workLogCount: Int?        // From /work
    let lastModified: Date
    let lastCommit: Commit?
    let status: ProjectStatus     // active, dormant, archived
}

enum ProjectStatus {
    case active      // Commits in last 7 days
    case inProgress  // Commits in last 30 days
    case dormant     // No commits in 30+ days
    case archived    // Marked as archived
}

6. Cool Features
GitHub-style Contribution Calendar:
* Heat map of daily activity
* Click a day to see what you worked on
* Streak tracking ("🔥 12 day streak!")
Quick Copy Actions:
* ⌘C on project → Copies GitHub URL
* ⌘⇧C on project → Copies git clone command
* Context menu with all options
Smart Sorting:
* Recent (last modified)
* Most active (commits)
* Alphabetical
* By language
* By status
Search:
* Filter by name
* Filter by language
* Filter by status
* Full-text search in README
Notifications:
* "You haven't committed to AFS in 3 days"
* "New PR on roguelike-dungeon"
* Daily summary (optional)

7. Tech Stack
┌─────────────────────────────────────────┐
│ macOS App (Swift + SwiftUI)             │
├─────────────────────────────────────────┤
│ UI Layer                                │
│ - SwiftUI for all views                 │
│ - Menu bar integration (NSStatusItem)   │
│ - Charts framework for graphs           │
├─────────────────────────────────────────┤
│ Data Layer                              │
│ - CoreData or SwiftData for caching     │
│ - FileManager for local scanning        │
│ - Process for git commands              │
├─────────────────────────────────────────┤
│ Network Layer                           │
│ - URLSession for GitHub API             │
│ - GraphQL for contribution data         │
│ - Async/await throughout                │
├─────────────────────────────────────────┤
│ Background                              │
│ - Scheduled refresh (every 15 min)      │
│ - File system watcher for changes       │
└─────────────────────────────────────────┘

8. Settings
┌─────────────────────────────────────────────────────────────────┐
│ Settings                                                        │
├─────────────────────────────────────────────────────────────────┤
│ General                                                         │
│   Code Directory: [~/Code            ] [Browse]                 │
│   Launch at Login: [✓]                                          │
│   Show in Menu Bar: [✓]                                         │
│                                                                 │
│ GitHub                                                          │
│   Personal Access Token: [••••••••••••••••] [Regenerate]       │
│   Sync Interval: [15 minutes ▼]                                │
│                                                                 │
│ Appearance                                                      │
│   Theme: [System ▼]                                            │
│   Accent Color: [🔵 Blue ▼]                                    │
│                                                                 │
│ Notifications                                                   │
│   Daily Summary: [✓] at [9:00 AM]                              │
│   Inactivity Alerts: [✓] after [3 days]                        │
│                                                                 │
│ Default Actions                                                 │
│   Open With: [VSCode ▼]                                        │
│   Terminal: [iTerm ▼]                                          │
│                                                                 │
│                                              [Save] [Cancel]    │
└─────────────────────────────────────────────────────────────────┘

9. File Structure
CodePulse/
├── CodePulse.xcodeproj
├── CodePulse/
│   ├── App/
│   │   ├── CodePulseApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarView.swift
│   │   │   └── MenuBarManager.swift
│   │   ├── Dashboard/
│   │   │   ├── DashboardView.swift
│   │   │   ├── ActivityCalendarView.swift
│   │   │   └── StatsCardsView.swift
│   │   ├── Projects/
│   │   │   ├── ProjectListView.swift
│   │   │   ├── ProjectRowView.swift
│   │   │   └── ProjectDetailView.swift
│   │   └── Settings/
│   │       └── SettingsView.swift
│   ├── Models/
│   │   ├── Project.swift
│   │   ├── Commit.swift
│   │   ├── WorkLog.swift
│   │   └── Prompt.swift
│   ├── Services/
│   │   ├── ProjectScanner.swift
│   │   ├── GitService.swift
│   │   ├── GitHubClient.swift
│   │   └── FileWatcher.swift
│   ├── Utilities/
│   │   ├── LineCounter.swift
│   │   ├── ReadmeParser.swift
│   │   └── DateExtensions.swift
│   └── Resources/
│       └── Assets.xcassets
└── README.md

Want me to write the first prompt to build this?
I can create a detailed spec/prompt for tCC (or a new agent) to build this Swift app. It would include:
1. Project setup
2. Core data models
3. Project scanner
4. Menu bar integration
5. Basic dashboard UI
Let me know! 🚀
