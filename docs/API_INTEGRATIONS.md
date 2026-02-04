# API Integrations

## Overview

ProjectStats integrates with several external APIs and CLI tools:

| Integration | Type | Purpose |
|-------------|------|---------|
| GitHub API | REST API | Repo stats, notifications |
| Anthropic OAuth API | REST API | Claude plan usage |
| ccusage CLI | CLI tool | Claude token usage |
| OpenAI API | REST API | Whisper, TTS, Embeddings |
| ElevenLabs API | REST API | Premium TTS |
| ntfy.sh | REST API | Push notifications |
| Messaging webhooks | REST API | Telegram, Slack, Discord |

---

## GitHub API

**Services:** `GitHubClient.swift`, `GitHubService.swift`

### Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/user` | GET | Get authenticated user info |
| `/notifications` | GET | Get unread notifications |
| `/repos/{owner}/{repo}` | GET | Get repository stats |
| `/notifications/threads/{id}` | PATCH | Mark notification as read |

### Authentication

Personal Access Token (PAT) with `repo` scope:
```swift
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
```

### Request Example

```swift
let url = URL(string: "https://api.github.com/notifications")!
var request = URLRequest(url: url)
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
```

### Response: Repository Stats

```json
{
  "stargazers_count": 150,
  "forks_count": 25,
  "open_issues_count": 8,
  "watchers_count": 150
}
```

### Rate Limits

- Authenticated: 5000 requests/hour
- Displayed in response headers: `X-RateLimit-Remaining`

---

## Anthropic OAuth API

**Service:** `ClaudePlanUsageService.swift`

### Endpoint

```
GET https://api.anthropic.com/api/oauth/usage
```

### Authentication

Bearer token read from Claude Code keychain:
```swift
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
request.setValue("claude-code/2.0.32", forHTTPHeaderField: "User-Agent")
```

### Token Retrieval

```swift
let query: [String: Any] = [
    kSecClass: kSecClassGenericPassword,
    kSecAttrService: "Claude Code-credentials",
    kSecReturnData: true,
    kSecMatchLimit: kSecMatchLimitOne
]

// Result contains JSON: {"claudeAiOauth": {"accessToken": "..."}}
```

### Response

```json
{
  "five_hour": {
    "utilization": 33.5,
    "resets_at": "2026-02-04T15:00:00Z"
  },
  "seven_day": {
    "utilization": 61.2,
    "resets_at": "2026-02-08T00:00:00Z"
  },
  "seven_day_opus": {
    "utilization": 25.0,
    "resets_at": "2026-02-08T00:00:00Z"
  },
  "seven_day_sonnet": {
    "utilization": 45.0,
    "resets_at": "2026-02-08T00:00:00Z"
  }
}
```

Note: `utilization` is returned as percentage (0-100), converted to decimal (0-1) in app.

### Polling

- Interval: Every 10 minutes
- Snapshots saved hourly to SwiftData

---

## ccusage CLI

**Service:** `ClaudeUsageService.swift`

### Command

```bash
npx ccusage@latest daily --json --since YYYYMMDD
```

### Execution

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["npx", "ccusage@latest", "daily", "--json", "--since", dateString]
process.currentDirectoryURL = projectURL  // For project-specific stats
```

### Response

```json
{
  "daily": [
    {
      "date": "2026-02-04",
      "inputTokens": 125000,
      "outputTokens": 45000,
      "cacheCreationTokens": 10000,
      "cacheReadTokens": 50000,
      "totalCost": 1.25
    }
  ],
  "total": {
    "inputTokens": 500000,
    "outputTokens": 180000,
    "totalCost": 5.50
  }
}
```

### Timeout

10-second timeout to prevent hanging:
```swift
DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
    if process.isRunning { process.terminate() }
}
```

---

## OpenAI API

**Services:** `TTSService.swift`, `VoiceNoteRecorder.swift`, `AIService.swift`

### Whisper (Speech-to-Text)

**Endpoint:** `POST https://api.openai.com/v1/audio/transcriptions`

```swift
var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
// Multipart form data with audio file
```

**Response:**
```json
{
  "text": "Transcribed text content"
}
```

### TTS (Text-to-Speech)

**Endpoint:** `POST https://api.openai.com/v1/audio/speech`

```swift
let body: [String: Any] = [
    "model": "tts-1",
    "voice": "alloy",
    "input": text
]
```

**Response:** Audio data (MP3)

### Embeddings

**Endpoint:** `POST https://api.openai.com/v1/embeddings`

```swift
let body: [String: Any] = [
    "model": "text-embedding-3-small",
    "input": text
]
```

**Response:**
```json
{
  "data": [
    {
      "embedding": [0.0023, -0.0045, ...]
    }
  ]
}
```

---

## ElevenLabs API

**Service:** `TTSService.swift`

### Endpoint

```
POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
```

### Request

```swift
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")

let body: [String: Any] = [
    "text": text,
    "model_id": "eleven_monolingual_v1"
]
```

### Response

Audio data (MP3)

---

## ntfy.sh

**Service:** `NotificationService.swift`, `NtfyProvider.swift`

### Endpoint

```
POST https://ntfy.sh/{topic}
```

### Request

```swift
var request = URLRequest(url: URL(string: "https://ntfy.sh/\(topic)")!)
request.httpMethod = "POST"
request.setValue(title, forHTTPHeaderField: "Title")
request.httpBody = message.data(using: .utf8)
```

### Features

- No authentication required for public topics
- Real-time push to mobile devices
- Free tier available

---

## Messaging Webhooks

### Telegram

**Service:** `TelegramProvider.swift`

```
POST https://api.telegram.org/bot{token}/sendMessage
```

```json
{
  "chat_id": "123456789",
  "text": "Message content"
}
```

### Slack

**Service:** `SlackProvider.swift`

```
POST {webhook_url}
```

```json
{
  "text": "Message content"
}
```

### Discord

**Service:** `DiscordProvider.swift`

```
POST {webhook_url}
```

```json
{
  "content": "Message content"
}
```

---

## Error Handling

### Common Patterns

```swift
do {
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }

    switch httpResponse.statusCode {
    case 200...299:
        // Success
    case 401:
        throw APIError.unauthorized
    case 429:
        throw APIError.rateLimited
    default:
        throw APIError.httpError(httpResponse.statusCode)
    }
} catch {
    self.error = error.localizedDescription
}
```

### Retry Logic

Currently no automatic retry. Manual refresh required.

---

## API Key Storage

| API | Storage Location | Key Name |
|-----|------------------|----------|
| GitHub | UserDefaults | `githubToken` |
| OpenAI | UserDefaults | `openai_apiKey` |
| ElevenLabs | UserDefaults | `elevenLabs_apiKey` |
| Anthropic | Keychain (Claude Code) | `Claude Code-credentials` |

Note: Sensitive keys in UserDefaults should ideally be migrated to Keychain.
