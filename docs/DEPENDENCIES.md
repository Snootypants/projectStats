# Dependencies

## Swift Package Dependencies

| Package | Version | Repository | Purpose |
|---------|---------|------------|---------|
| SwiftTerm | 1.10.0 | github.com/migueldeicaza/SwiftTerm | Terminal emulator component |
| swift-argument-parser | 1.7.0 | github.com/apple/swift-argument-parser | Command line argument parsing (transitive) |

### SwiftTerm

SwiftTerm provides the terminal emulator used in:
- `TerminalTabView.swift` — Main terminal component
- `TerminalPanelView.swift` — Terminal container

Features used:
- PTY-based terminal emulation
- ANSI color support
- Keyboard input handling
- Scrollback buffer

---

## System Frameworks

| Framework | Import | Purpose |
|-----------|--------|---------|
| SwiftUI | `import SwiftUI` | Declarative UI framework |
| SwiftData | `import SwiftData` | Persistence with @Model |
| CloudKit | `import CloudKit` | iCloud sync backend |
| AVFoundation | `import AVFoundation` | Audio recording/playback |
| Security | `import Security` | Keychain access |
| UserNotifications | `import UserNotifications` | Local notifications |
| Network | `import Network` | Network path monitoring |
| ServiceManagement | `import ServiceManagement` | Launch at login |
| GameKit | `import GameKit` | Game Center achievements |
| AppKit | `import AppKit` | macOS UI, NSApp |
| Foundation | `import Foundation` | Core utilities |
| Combine | `import Combine` | Reactive programming |

### SwiftData Models

```swift
@Model
final class CachedProject {
    var path: String
    // ...
}
```

Used for all persistent data with automatic CloudKit sync capability.

### CloudKit

Custom zone: `ProjectStatsZone`
Record types: `SavedPrompt`, `SavedDiff`, `AISessionV2`, `TimeEntry`

### Security (Keychain)

Used to read Claude Code OAuth token:
```swift
let query: [String: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "Claude Code-credentials",
    kSecReturnData: true
]
```

---

## External CLI Tools

| Tool | Command | Purpose | Required? |
|------|---------|---------|-----------|
| git | `git` | Version control operations | Yes |
| claude | `claude` | Claude Code CLI | Optional |
| codex | `codex` | Codex CLI | Optional |
| npx | `npx ccusage@latest` | Token usage parsing | Optional |
| zip | `zip` | Project backup | Yes (macOS built-in) |

### Git

Used extensively via `Shell.run()`:
```swift
Shell.run("git log -1 --format=\"%H|%s|%an|%ai\"", at: path)
Shell.run("git status --porcelain", at: path)
Shell.run("git rev-list --count HEAD", at: path)
```

### Claude Code

Detected via terminal output patterns:
- `╭─` — Prompt box start
- `✻ Cooked for` — Session complete

OAuth token read from keychain for plan usage API.

### ccusage

NPM package for parsing Claude Code JSONL files:
```bash
npx ccusage@latest daily --json --since 20260101
```

Returns JSON with token counts and costs.

---

## External APIs

| API | Purpose | Auth Method |
|-----|---------|-------------|
| GitHub API | Repo stats, notifications | Personal Access Token |
| Anthropic OAuth API | Plan usage percentage | Bearer token (from Claude Code) |
| OpenAI API | Whisper STT, TTS, Embeddings | API key |
| ElevenLabs API | Premium TTS | API key |
| ntfy.sh | Push notifications | None (public topics) |

### Rate Limits

| API | Limit |
|-----|-------|
| GitHub API | 5000 requests/hour (authenticated) |
| Anthropic OAuth | Unknown (usage endpoint) |
| OpenAI API | Varies by model/tier |
| ntfy.sh | Fair use |

---

## Optional Integrations

These features require external services but the app works without them:

| Feature | Requires | Fallback |
|---------|----------|----------|
| GitHub stats | GitHub PAT | Shows "No token" |
| Plan usage | Claude Code installed | Hidden card |
| Token usage | npx/ccusage | Hidden card |
| Voice notes | OpenAI API key | Feature disabled |
| TTS playback | OpenAI/ElevenLabs key | Feature disabled |
| Push notifications | ntfy.sh topic | Local only |
| iCloud sync | iCloud signed in | Local only |

---

## Build Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 14.0 (Sonoma) or later |
| Xcode | 15.0 or later |
| Swift | 5.9 or later |
| iOS SDK | N/A (macOS only) |

---

## Dependency Graph

```
ProjectStats
├── SwiftTerm (terminal emulator)
│   └── swift-argument-parser (transitive)
├── System Frameworks
│   ├── SwiftUI (UI)
│   ├── SwiftData (persistence)
│   ├── CloudKit (sync)
│   ├── AVFoundation (audio)
│   ├── Security (keychain)
│   ├── UserNotifications (notifications)
│   └── ...
└── External Services (optional)
    ├── GitHub API
    ├── Anthropic API
    ├── OpenAI API
    ├── ElevenLabs API
    └── ntfy.sh
```

---

## Updating Dependencies

### SwiftTerm

1. Open `projectStats.xcodeproj`
2. Select project in navigator
3. Package Dependencies tab
4. Update to desired version

### System Frameworks

System frameworks are bundled with macOS/Xcode. Update by changing:
- Deployment target in Xcode
- SDK version in Xcode

### External APIs

API integrations are version-agnostic REST calls. Monitor for:
- Endpoint changes
- Authentication changes
- Rate limit changes
