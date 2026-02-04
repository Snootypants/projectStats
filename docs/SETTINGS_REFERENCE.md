# Settings Reference

## Overview

All settings are stored using `@AppStorage` (UserDefaults). This document lists every key used in the codebase.

**Total @AppStorage keys:** 75+

---

## General Settings

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `codeDirectoryPath` | String | "" | SettingsViewModel | Root directory to scan for projects |
| `githubToken` | String | "" | SettingsViewModel | GitHub Personal Access Token |
| `defaultEditorRaw` | String | "Visual Studio Code" | SettingsViewModel | Default editor (raw value) |
| `defaultTerminalRaw` | String | "Terminal" | SettingsViewModel | Default terminal (raw value) |
| `refreshInterval` | Int | 15 | SettingsViewModel | Project refresh interval in minutes |
| `launchAtLogin` | Bool | false | SettingsViewModel | Launch app at login |
| `showInDock` | Bool | false | SettingsViewModel | Show app icon in Dock |

---

## Appearance Settings

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `themeRaw` | String | "System" | SettingsViewModel | App theme (raw value) |
| `accentColorHex` | String | "#FF9500" | SettingsView, IDEModeView | Accent color hex |
| `dividerGlowOpacity` | Double | 0.5 | SettingsView, IDEModeView | Divider glow opacity |
| `dividerGlowRadius` | Double | 3.0 | SettingsView, IDEModeView | Divider glow blur radius |
| `dividerLineThickness` | Double | 2.0 | SettingsView, IDEModeView | Divider line thickness |
| `dividerBarOpacity` | Double | 1.0 | SettingsView, IDEModeView | Divider bar opacity |
| `previewDividerGlow` | Bool | false | SettingsView, IDEModeView | Preview glow effect |

---

## Notification Settings

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `notifyClaudeFinished` | Bool | true | SettingsViewModel | Notify when Claude session ends |
| `playSoundOnClaudeFinished` | Bool | true | SettingsViewModel | Play sound with notification |
| `notificationSound` | String | "Ping" | SettingsViewModel | Sound name for notifications |
| `notifyBuildComplete` | Bool | true | SettingsViewModel | Notify on build complete |
| `notifyServerStart` | Bool | true | SettingsViewModel | Notify when dev server starts |
| `notifyContextHigh` | Bool | true | SettingsViewModel | Notify when context > 80% |
| `notifyPlanUsageHigh` | Bool | true | SettingsViewModel | Notify when plan > 75% |
| `notifyGitPushCompleted` | Bool | false | SettingsViewModel | Notify on git push |
| `notifyAchievementUnlocked` | Bool | false | SettingsViewModel | Notify on achievement |
| `pushNotificationsEnabled` | Bool | false | SettingsViewModel | Enable ntfy.sh push |
| `ntfyTopic` | String | "projectstats-caleb" | SettingsViewModel | ntfy.sh topic name |

---

## Messaging Settings

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `messaging.service` | String | "telegram" | SettingsViewModel | Active messaging service |
| `messaging.telegram.token` | String | "" | SettingsViewModel | Telegram bot token |
| `messaging.telegram.chat` | String | "" | SettingsViewModel | Telegram chat ID |
| `messaging.slack.webhook` | String | "" | SettingsViewModel | Slack webhook URL |
| `messaging.discord.webhook` | String | "" | SettingsViewModel | Discord webhook URL |
| `messaging.ntfy.topic` | String | "" | SettingsViewModel | Messaging ntfy topic |
| `messaging.notifications.enabled` | Bool | false | SettingsViewModel | Send to messaging service |
| `messaging.remote.enabled` | Bool | false | SettingsViewModel | Enable remote commands |
| `messaging.remote.interval` | Int | 30 | SettingsViewModel | Remote poll interval (seconds) |

---

## AI Provider Settings

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `ai.provider` | String | "anthropic" | SettingsViewModel | Legacy AI provider |
| `ai.apiKey` | String | "" | SettingsViewModel | Legacy AI API key |
| `ai.model` | String | "claude-3-5-sonnet-latest" | SettingsViewModel | Legacy AI model |
| `ai.baseUrl` | String | "" | SettingsViewModel | Custom API base URL |
| `ai.defaultModel` | String | "claude-sonnet-4-5-20250514" | SettingsViewModel | Default AI model |
| `ai.defaultThinkingLevel` | String | "none" | SettingsViewModel | Default thinking level |
| `ai.showModelInToolbar` | Bool | true | SettingsViewModel | Show model in toolbar |

---

## API Keys

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `openai_apiKey` | String | "" | SettingsViewModel | OpenAI API key (Whisper, TTS) |
| `elevenLabs_apiKey` | String | "" | SettingsViewModel | ElevenLabs API key |
| `elevenLabs_voiceId` | String | "" | SettingsViewModel | ElevenLabs voice ID |

---

## Voice Settings

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `tts_enabled` | Bool | false | SettingsViewModel | Enable text-to-speech |
| `tts_provider` | String | "openai" | SettingsViewModel | TTS provider ("openai" or "elevenlabs") |
| `voice_autoTranscribe` | Bool | true | SettingsViewModel | Auto-transcribe voice notes |

---

## Claude Usage Display Settings

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `ccusage_showCost` | Bool | true | SettingsViewModel | Show cost in usage card |
| `ccusage_showChart` | Bool | true | SettingsViewModel | Show 7-day chart |
| `ccusage_showInputTokens` | Bool | false | SettingsViewModel | Show input tokens |
| `ccusage_showOutputTokens` | Bool | false | SettingsViewModel | Show output tokens |
| `ccusage_showCacheTokens` | Bool | false | SettingsViewModel | Show cache tokens |
| `ccusage_showModelBreakdown` | Bool | false | SettingsViewModel | Show per-model breakdown |
| `ccusage_daysToShow` | Int | 7 | SettingsViewModel | Days of history to show |

---

## IDE Tab Visibility

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `showPromptsTab` | Bool | true | SettingsViewModel, IDEModeView | Show Prompts tab |
| `showDiffsTab` | Bool | true | SettingsViewModel, IDEModeView | Show Diffs tab |
| `showEnvironmentTab` | Bool | true | SettingsViewModel, IDEModeView | Show Environment tab |

---

## Workspace Layout

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `workspace.terminalWidth` | Double | 450 | IDEModeView | Terminal panel width |
| `workspace.explorerWidth` | Double | 200 | IDEModeView | File browser width |
| `workspace.viewerWidth` | Double | 450 | IDEModeView | Code viewer width |
| `workspace.showTerminal` | Bool | true | IDEModeView | Show terminal panel |
| `workspace.showExplorer` | Bool | true | IDEModeView | Show file browser |
| `workspace.showViewer` | Bool | true | IDEModeView | Show code viewer |

---

## File Browser

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `showHiddenFiles` | Bool | false | FileBrowserView | Show hidden files (.*) |

---

## iCloud Sync Settings

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `sync.enabled` | Bool | false | SyncSettingsView | Enable iCloud sync |
| `sync.prompts` | Bool | true | SyncSettingsView | Sync prompts |
| `sync.diffs` | Bool | true | SyncSettingsView | Sync diffs |
| `sync.aiSessions` | Bool | true | SyncSettingsView | Sync AI sessions |
| `sync.timeEntries` | Bool | true | SyncSettingsView | Sync time entries |
| `sync.achievements` | Bool | true | SyncSettingsView | Sync achievements |
| `sync.automatic` | Bool | true | SyncSettingsView | Auto-sync on changes |
| `sync.intervalMinutes` | Int | 15 | SyncSettingsView | Sync interval |

---

## Custom Cloud Sync (Legacy)

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `sync.endpoint` | String | "" | CloudSyncService | Custom sync endpoint |
| `sync.apiKey` | String | "" | CloudSyncService | Custom sync API key |
| `sync.include.chat` | Bool | true | CloudSyncService | Include chat messages |
| `sync.include.projects` | Bool | true | CloudSyncService | Include project stats |
| `sync.include.usage` | Bool | true | CloudSyncService | Include Claude usage |
| `sync.include.time` | Bool | true | CloudSyncService | Include time tracking |
| `sync.include.achievements` | Bool | true | CloudSyncService | Include achievements |
| `sync.frequencyMinutes` | Int | 60 | CloudSyncService | Sync frequency |

---

## Achievement Progress

| Key | Type | Default | Location | Description |
|-----|------|---------|----------|-------------|
| `achievement.nightOwlCount` | Int | 0 | AchievementService | Night owl progress |
| `achievement.earlyBirdCount` | Int | 0 | AchievementService | Early bird progress |
| `achievement.lastCommitDate` | String | "" | AchievementService | Last commit date string |

---

## Internal Keys

These are used internally and not directly user-configurable:

| Key | Type | Location | Description |
|-----|------|----------|-------------|
| `openTabs` | Data | TabManagerViewModel | Serialized tab state |
| `activeTabIndex` | Int | TabManagerViewModel | Active tab index |
| `favoriteTabProjects` | Data | TabManagerViewModel | Favorite project paths |
| `cloudkit.serverChangeToken` | Data | SyncEngine | CloudKit change token |

---

## How to Add New Settings

1. Add `@AppStorage` property to `SettingsViewModel`:
```swift
@AppStorage("my_new_setting") var myNewSetting: Bool = false
```

2. Add UI in appropriate settings section:
```swift
Toggle("My New Setting", isOn: $settings.myNewSetting)
```

3. Document in this file under appropriate section.

## Settings Migration

When changing setting keys or defaults:
1. Old values remain in UserDefaults
2. Consider migration logic in `DataMigrationService` if needed
3. Users may have old values that need handling
