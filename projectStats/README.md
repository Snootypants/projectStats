# ProjectStats

A native macOS menu bar app for developers to track coding activity across all their projects. Built with SwiftUI and SwiftData.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### Dashboard
- **Overview Tab**: Quick stats cards showing lines of code and commits for today, this week, this month, and all time
- **Activity Heatmap**: GitHub-style contribution calendar showing your coding activity over the past year
- **Recent Projects**: Grid view of your most recently active projects

### Project Management
- **Automatic Discovery**: Scans your code directory to find all git repositories
- **Project Details**: View line counts, file counts, commit history, README previews, and more
- **Project Grouping**: Combine related projects (monorepos, multi-version projects) into logical groups
- **Status Tracking**: Projects are automatically categorized as Active, In Progress, or Dormant based on commit recency
- **JSON Stats Integration**: Reads `projectstats.json` files for pre-computed accurate statistics

### Menu Bar
- **Quick Access**: Always-available menu bar icon showing today's stats and recent projects
- **One-Click Actions**: Open projects in your editor, Finder, or GitHub directly from the menu bar

### IDE Mode
- **File Browser**: Navigate project files without leaving the app
- **File Viewer**: Syntax-highlighted code viewing
- **Prompt Manager**: Manage AI prompt files in your projects

### Git Integration
- **Commit History**: View recent commits with line change stats
- **Branch Info**: See current branch, total commits, and first commit date
- **Activity Metrics**: Track commits and line changes over 7-day and 30-day windows
- **GitHub Stats**: Fetch stars, forks, and issues for your public repositories (requires token)

## Screenshots

*Dashboard with activity heatmap and project grid*

*Project detail view with git metrics and README preview*

## Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building from source)

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/Snootypants/projectStats.git
   cd projectStats/projectStats
   ```

2. Open in Xcode:
   ```bash
   open projectStats.xcodeproj
   ```

3. Build and run (⌘R)

## Configuration

### Settings

Access settings via the gear icon in the sidebar or **ProjectStats > Settings** in the menu bar.

#### General
| Setting | Description | Default |
|---------|-------------|---------|
| Code Directory | Root folder to scan for projects | `~/Code` |
| Default Editor | Editor to open projects in | VS Code |
| Default Terminal | Terminal app for command line access | Terminal |
| Refresh Interval | How often to rescan projects (minutes) | 15 |
| Launch at Login | Start ProjectStats when you log in | Off |
| Show in Dock | Display app icon in the Dock | Off |

#### Appearance
| Setting | Description | Default |
|---------|-------------|---------|
| Theme | Light, Dark, or System | System |

#### GitHub
| Setting | Description |
|---------|-------------|
| Personal Access Token | Optional. Enables fetching repository stats (stars, forks, issues). Requires `repo` scope. |

### projectstats.json

ProjectStats can read pre-computed statistics from `projectstats.json` files placed at the root of each project. When present, these files are used as the primary data source instead of scanning.

#### Schema

```json
{
  "name": "Project Name",
  "description": "Brief project description",
  "status": "active",
  "language": "TypeScript",
  "languages": {
    "TypeScript": 5000,
    "JavaScript": 1200,
    "CSS": 800
  },
  "lineCount": 7000,
  "fileCount": 45,
  "structure": "monorepo",
  "structureNotes": "pnpm workspace with apps/ and packages/",
  "sourceDirectories": ["src/", "lib/"],
  "excludedDirectories": ["node_modules/", "dist/"],
  "techStack": ["React", "TypeScript", "Vite", "Tailwind CSS"],
  "git": {
    "remoteUrl": "https://github.com/user/repo.git",
    "currentBranch": "main",
    "defaultBranch": "main",
    "firstCommitDate": "2024-01-15T10:30:00Z",
    "lastCommitDate": "2024-03-20T14:22:00Z",
    "lastCommitMessage": "feat: add new feature",
    "totalCommits": 156,
    "branches": ["main", "develop", "feature/new-thing"]
  },
  "generatedAt": "2024-03-20T15:00:00Z",
  "generatedBy": "claude-code-audit"
}
```

#### Status Values

| Status | Description | Counts in Totals |
|--------|-------------|------------------|
| `active` | Currently being worked on | Yes |
| `paused` | Temporarily on hold | Yes |
| `experimental` | Proof of concept or playground | Yes |
| `archived` | Complete, no longer maintained | No |
| `abandoned` | Discontinued | No |

Projects with `archived` or `abandoned` status appear dimmed in the UI and are excluded from aggregate statistics.

## Project Structure

```
projectStats/
├── App/
│   └── ProjectStatsApp.swift       # App entry point
├── Models/
│   ├── Project.swift               # Project model
│   ├── CachedModels.swift          # SwiftData persistence
│   ├── Commit.swift                # Git commit model
│   ├── ActivityStats.swift         # Daily activity aggregation
│   ├── GitRepoInfo.swift           # Git repository metadata
│   └── ProjectGroup.swift          # Project grouping
├── Services/
│   ├── ProjectScanner.swift        # Repository discovery
│   ├── JSONStatsReader.swift       # projectstats.json parser
│   ├── LineCounter.swift           # Source code analysis
│   ├── GitService.swift            # Git operations
│   ├── GitRepoService.swift        # Git repo inspection
│   └── GitHubClient.swift          # GitHub API client
├── ViewModels/
│   ├── DashboardViewModel.swift    # Main data orchestration
│   ├── ProjectListViewModel.swift  # Project filtering/sorting
│   └── SettingsViewModel.swift     # App preferences
├── Views/
│   ├── Dashboard/                  # Overview, stats, charts
│   ├── Projects/                   # Project list and details
│   ├── MenuBar/                    # Menu bar extra
│   ├── IDE/                        # File browser and viewer
│   └── Settings/                   # Preferences UI
└── Utilities/
    ├── Shell.swift                 # Shell command execution
    ├── DateExtensions.swift        # Date utilities
    ├── URLExtensions.swift         # File system helpers
    └── ReadmeParser.swift          # README extraction
```

## Supported Languages

ProjectStats detects and counts lines for these file types:

| Category | Extensions |
|----------|------------|
| **Web** | `.ts`, `.tsx`, `.js`, `.jsx`, `.html`, `.css`, `.scss`, `.sass`, `.less`, `.vue`, `.svelte`, `.astro` |
| **Backend** | `.py`, `.rb`, `.php` |
| **Systems** | `.swift`, `.rs`, `.go`, `.c`, `.cpp`, `.h`, `.hpp`, `.cs`, `.java`, `.kt`, `.kts` |
| **Data/Config** | `.sql`, `.json`, `.yaml`, `.yml`, `.toml`, `.xml` |
| **Scripts** | `.sh`, `.bash`, `.zsh` |
| **Docs** | `.md`, `.markdown` |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘R | Refresh project data |
| ⌘, | Open Settings |
| ⌘1 | Overview tab |
| ⌘2 | Projects tab |
| ⌘3 | Activity tab |

## Data Storage

ProjectStats stores data locally using SwiftData:

- **Cache Location**: `~/Library/Application Support/projectStats/`
- **Cached Data**: Project metadata, daily activity stats
- **Settings**: Stored in UserDefaults

No data is sent to external servers except:
- GitHub API requests (if you provide a token)
- Git operations to your configured remotes

## Troubleshooting

### Projects not appearing
- Ensure your code directory is set correctly in Settings
- Projects must have a `.git` folder or recognized project files (`package.json`, `Cargo.toml`, etc.)
- Check that the directory isn't in the excluded list (node_modules, .build, etc.)

### GitHub stats not loading
- Verify your Personal Access Token in Settings
- Use the "Test Connection" button to validate
- Token requires `repo` scope for private repositories

### High CPU usage during scan
- Large repositories with many files take longer to scan
- Consider using `projectstats.json` for large projects to skip file counting

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/) and [SwiftData](https://developer.apple.com/xcode/swiftdata/)
- Git operations inspired by [libgit2](https://libgit2.org/)
- Activity heatmap inspired by [GitHub's contribution graph](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-github-profile/managing-contribution-settings-on-your-profile/viewing-contributions-on-your-profile)
