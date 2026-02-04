# ProjectStats

A native macOS developer dashboard for tracking coding activity, AI usage, and project statistics across all your projects.

## What is ProjectStats?

ProjectStats is a comprehensive development analytics tool built natively for macOS. It provides real-time insights into your coding activity, tracks time spent on projects, monitors Claude Code and other AI tool usage, and displays Git metrics — all from a sleek, tabbed interface or a quick-access menu bar widget.

The app automatically discovers projects in your code directory, tracks commits and line changes, monitors terminal output for Claude Code sessions, and aggregates statistics across all your work. Whether you want to see how much time you've spent coding today, check your Claude plan usage percentage, or review your commit streak, ProjectStats keeps all your development metrics in one place.

Built with SwiftUI and SwiftData, ProjectStats embraces modern Apple frameworks while providing powerful features like iCloud sync, achievement tracking, voice notes with Whisper transcription, and multi-provider AI integration support.

## Screenshots

Screenshots to capture:
- Home dashboard with activity cards
- Project workspace with terminal, file browser, and prompts panel
- Menu bar quick access popover
- Settings window with sidebar navigation
- Focus mode during Claude sessions
- Achievements dashboard

## Features

### Core Features
- **Chrome-style Tab Bar**: Open multiple projects in tabs with state persistence
- **Home Dashboard**: Stats cards, activity heatmap, GitHub notifications, recent projects
- **Project Workspaces**: Integrated file browser, code viewer, terminal, prompts manager
- **Menu Bar Widget**: Quick access to stats and recent projects
- **Focus Mode**: Distraction-free view during AI coding sessions

### AI Integration
- **Claude Code Monitoring**: Detects sessions, tracks duration, triggers notifications
- **Codex CLI Support**: Integration with OpenAI's Codex CLI tool
- **Multi-Provider Tracking**: Support for Anthropic, OpenAI, Ollama models
- **Plan Usage Tracking**: Real-time 5h/7d utilization from Anthropic OAuth API
- **Token Usage via ccusage**: Parse local JSONL files for cost tracking

### Time & Activity Tracking
- **Automatic Time Tracking**: Separate human vs AI coding time
- **Activity Heatmap**: GitHub-style contribution calendar
- **Git Metrics**: Commits, lines added/removed over 7d/30d windows
- **Daily/Weekly Aggregates**: Pre-computed metrics for fast dashboard loading

### Data & Sync
- **SwiftData Persistence**: Local database with automatic migrations
- **iCloud Sync**: CloudKit-based sync for prompts, diffs, sessions, time entries
- **Offline Queue**: Changes queued when offline, synced when reconnected
- **Backup & Export**: Zip project backups, Markdown exports

### Notifications
- **Local Notifications**: Claude finished, build complete, high context usage
- **Push Notifications**: ntfy.sh integration for mobile alerts
- **Messaging Integrations**: Telegram, Slack, Discord webhooks

### Achievements & Gamification
- **22 Achievements**: From "First Blood" to "Context Master"
- **XP System**: Earn points, level up
- **Progress Tracking**: Night owl, early bird, streaks, and more
- **Game Center Integration**: Report achievements (optional)

### Voice & Audio
- **Voice Notes**: Record voice memos with Whisper transcription
- **TTS Playback**: Listen to content via OpenAI or ElevenLabs

## Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building from source)
- Swift 5.9+

### Build Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/projectStats.git
   cd projectStats/projectStats
   ```

2. Open in Xcode:
   ```bash
   open projectStats.xcodeproj
   ```

3. Build and run (Cmd+R)

### Configuration
1. **Set Code Directory**: Settings > General > Code Directory (default: `~/Code`)
2. **GitHub Token** (optional): Settings > General > Personal Access Token (for repo stats)
3. **OpenAI API Key** (optional): Settings > AI > OpenAI API Key (for Whisper/TTS)
4. **ElevenLabs API Key** (optional): Settings > AI > ElevenLabs (for premium TTS)

## Usage

### Opening Projects
1. Click "+" or Cmd+Shift+T to open a new tab
2. Select a project from the picker
3. The workspace opens with file browser, terminal, and tool panels

### Monitoring Claude Sessions
- Claude Code sessions are automatically detected when running `claude` in the terminal
- Notifications fire when sessions complete (if app/tab not focused)
- Plan usage percentage updates every 10 minutes

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| Cmd+Shift+F | Enter Focus Mode |
| Cmd+Shift+T | New Tab |
| Cmd+Shift+W | Close Tab |
| Cmd+Option+1-9 | Switch to Tab N |
| Cmd+K | Command Palette |
| Cmd+, | Settings |

## Tech Stack

- **SwiftUI** — Declarative UI framework
- **SwiftData** — Persistence with CloudKit sync
- **SwiftTerm** — Terminal emulator
- **CloudKit** — iCloud sync backend
- **AVFoundation** — Audio recording/playback
- **Security** — Keychain access for OAuth tokens
- **UserNotifications** — Local and push notifications

## Architecture

ProjectStats follows an MVVM architecture with singleton services:

```
Views (SwiftUI) → ViewModels (@Observable) → Services (Singletons) → Models (SwiftData)
```

Key architectural patterns:
- **Singleton Services**: Shared instances for cross-cutting concerns
- **@MainActor**: UI updates on main thread
- **Async/Await**: Modern concurrency throughout
- **CloudKit Sync**: Push/pull with change tokens and conflict resolution

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Acknowledgments

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) for terminal emulation
- [ntfy.sh](https://ntfy.sh) for push notification infrastructure
- [ccusage](https://github.com/anthropics/ccusage) for Claude Code token parsing
