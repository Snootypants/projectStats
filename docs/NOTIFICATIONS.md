# Notifications

## Overview

ProjectStats supports three notification channels:
1. **Local notifications** — macOS notification center
2. **Push notifications** — ntfy.sh
3. **Messaging integrations** — Telegram, Slack, Discord

---

## Local Notifications

**Service:** `NotificationService.swift`
**Framework:** UserNotifications

### Triggers

| Trigger | Setting Key | Title | Condition |
|---------|-------------|-------|-----------|
| Claude finishes | `notifyClaudeFinished` | "Claude finished" | Tab not active or app not focused |
| Build complete | `notifyBuildComplete` | "Build complete" | Build succeeds/fails (detected) |
| Server starts | `notifyServerStart` | "Dev server started" | Port detected in output |
| Context high | `notifyContextHigh` | "Context high" | Context % > 80% |
| Plan usage high | `notifyPlanUsageHigh` | "Plan usage high" | 5h utilization > 75% |
| Git push | `notifyGitPushCompleted` | "Git push completed" | Push succeeds |
| Achievement | `notifyAchievementUnlocked` | "Achievement Unlocked" | Achievement earned |

### Implementation

```swift
func sendNotification(title: String, message: String, sound: Bool = true) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message

    if sound, settings.playSoundOnClaudeFinished {
        content.sound = UNNotificationSound(named: UNNotificationSoundName(settings.notificationSound))
    }

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil  // Deliver immediately
    )

    UNUserNotificationCenter.current().add(request)
}
```

### Sound Options

Configured via `notificationSound` setting:
- "Ping" (default)
- "Pop"
- "Sosumi"
- "Submarine"
- "Glass"
- Custom sounds in app bundle

### Authorization

Requested on first launch:
```swift
UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge]
)
```

### Foreground Behavior

Notifications shown even when app is active (via delegate):
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           willPresent notification: UNNotification,
                           withCompletionHandler: ...) {
    completionHandler([.banner, .sound])
}
```

---

## Push Notifications (ntfy.sh)

**Service:** `NotificationService.swift`
**Setting:** `pushNotificationsEnabled`, `ntfyTopic`

### Endpoint

```
POST https://ntfy.sh/{topic}
```

### Request

```swift
func sendPushNotification(title: String, message: String) async {
    guard let url = URL(string: "https://ntfy.sh/\(settings.ntfyTopic)") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(title, forHTTPHeaderField: "Title")
    request.httpBody = message.data(using: .utf8)

    _ = try? await URLSession.shared.data(for: request)
}
```

### Setup

1. Install ntfy app on phone
2. Subscribe to topic (e.g., "projectstats-yourname")
3. Enter same topic in Settings > Notifications > ntfy Topic
4. Enable "Push Notifications"

### Triggers

Same triggers as local notifications (sent in parallel).

---

## Messaging Integrations

**Service:** `MessagingService.swift`
**Setting:** `messagingNotificationsEnabled`, `messaging.service`

### Providers

| Provider | Service File | Auth Method |
|----------|--------------|-------------|
| Telegram | `TelegramProvider.swift` | Bot token + Chat ID |
| Slack | `SlackProvider.swift` | Incoming webhook URL |
| Discord | `DiscordProvider.swift` | Webhook URL |
| ntfy | `NtfyProvider.swift` | Topic name |

### Telegram Setup

1. Create bot via @BotFather
2. Get chat ID (send message to bot, check updates API)
3. Enter bot token and chat ID in Settings

```swift
POST https://api.telegram.org/bot{token}/sendMessage
{
    "chat_id": "{chat_id}",
    "text": "Claude finished: Ready for review in ProjectStats"
}
```

### Slack Setup

1. Create Incoming Webhook in Slack workspace
2. Copy webhook URL to Settings

```swift
POST {webhook_url}
{
    "text": "Claude finished: Ready for review in ProjectStats"
}
```

### Discord Setup

1. Create Webhook in Discord server settings
2. Copy webhook URL to Settings

```swift
POST {webhook_url}
{
    "content": "Claude finished: Ready for review in ProjectStats"
}
```

### Message Format

```swift
"[\(projectName)] \(title): \(message)"
```

Example: `[ProjectStats] Claude finished: Ready for review`

---

## Internal Notifications (NotificationCenter)

**File:** `Utilities/NotificationNames.swift`

### Notification Names

| Name | Purpose | Payload |
|------|---------|---------|
| `.enterFocusMode` | Trigger focus mode UI | None |
| `.requestDocUpdate` | Request document refresh | `projectPath: String` |

### Usage

**Posting:**
```swift
NotificationCenter.default.post(name: .enterFocusMode, object: nil)
```

**Observing:**
```swift
.onReceive(NotificationCenter.default.publisher(for: .enterFocusMode)) { _ in
    showFocusMode = true
}
```

---

## Notification Logic

### Claude Finished

```swift
func checkAndNotifyClaudeFinished() {
    let isAppActive = NSApp.isActive
    let activeContent = TabManagerViewModel.shared.activeTab?.content
    var isTabActive = false

    if case .projectWorkspace(let path) = activeContent {
        isTabActive = path == activeProjectPath
    }

    // Only notify if app not focused OR project tab not active
    if !isAppActive || !isTabActive {
        NotificationService.shared.sendNotification(
            title: "Claude finished",
            message: "Ready for review in \(projectName)"
        )
    }
}
```

### Plan Usage High

```swift
// In ClaudePlanUsageService.fetchUsage()
if fiveHourUtilization >= 0.75, !hasNotifiedHighUsage {
    NotificationService.shared.sendNotification(
        title: "Plan usage high",
        message: "Claude usage is at \(Int(fiveHourUtilization * 100))% of the 5h window."
    )
    hasNotifiedHighUsage = true
}

// Reset flag when usage drops
if fiveHourUtilization < 0.6 {
    hasNotifiedHighUsage = false
}
```

---

## Notification Settings UI

Located in: `Views/Settings/NotificationSettings.swift`

```swift
Section("Local Notifications") {
    Toggle("Claude finished", isOn: $settings.notifyClaudeFinished)
    Toggle("Play sound", isOn: $settings.playSoundOnClaudeFinished)
    Picker("Sound", selection: $settings.notificationSound) { ... }
    Toggle("Build complete", isOn: $settings.notifyBuildComplete)
    Toggle("Dev server start", isOn: $settings.notifyServerStart)
    Toggle("High context usage", isOn: $settings.notifyContextHigh)
    Toggle("High plan usage", isOn: $settings.notifyPlanUsageHigh)
    Toggle("Git push completed", isOn: $settings.notifyGitPushCompleted)
    Toggle("Achievement unlocked", isOn: $settings.notifyAchievementUnlocked)
}

Section("Push Notifications") {
    Toggle("Enable ntfy.sh", isOn: $settings.pushNotificationsEnabled)
    TextField("Topic", text: $settings.ntfyTopic)
}
```
