# ProjectStats Web API Specification

## Overview

REST API for 35bird.io web dashboard integration with ProjectStats app.

**Base URL:** `https://api.35bird.io/v1`

**Authentication:** Bearer token (JWT)

## Authentication

All endpoints require authentication via Bearer token:

```
Authorization: Bearer <jwt_token>
```

## Endpoints

### Projects

#### GET /projects
List all projects for the authenticated user.

**Response:**
```json
{
  "projects": [
    {
      "id": "uuid",
      "name": "project-name",
      "path": "/path/to/project",
      "lastCommit": "2024-01-15T10:30:00Z",
      "totalCommits": 150,
      "totalLines": 25000
    }
  ]
}
```

#### GET /projects/:id
Get details for a specific project.

### Prompts

#### GET /prompts
List all saved prompts.

**Query Parameters:**
- `project_id` (optional): Filter by project
- `limit` (optional, default: 50): Max results
- `offset` (optional): Pagination offset

#### POST /prompts
Create a new prompt.

**Body:**
```json
{
  "text": "prompt text",
  "projectPath": "/path/to/project"
}
```

#### DELETE /prompts/:id
Delete a prompt.

### Diffs

#### GET /diffs
List all saved diffs.

**Query Parameters:**
- `project_id` (optional): Filter by project
- `limit` (optional, default: 50): Max results

#### GET /diffs/:id
Get a specific diff.

### Sessions

#### GET /sessions
List AI sessions.

**Query Parameters:**
- `project_id` (optional): Filter by project
- `provider` (optional): Filter by provider type
- `since` (optional): ISO date for filtering
- `limit` (optional, default: 100): Max results

**Response:**
```json
{
  "sessions": [
    {
      "id": "uuid",
      "providerType": "claude_code",
      "model": "claude-sonnet-4-5-20250514",
      "startTime": "2024-01-15T10:30:00Z",
      "endTime": "2024-01-15T10:35:00Z",
      "inputTokens": 5000,
      "outputTokens": 2000,
      "costUSD": 0.05
    }
  ]
}
```

### Time Entries

#### GET /time-entries
List time entries.

**Query Parameters:**
- `project_id` (optional): Filter by project
- `start_date` (optional): Start of date range
- `end_date` (optional): End of date range

#### POST /time-entries
Create a time entry.

### Achievements

#### GET /achievements
List unlocked achievements.

#### GET /achievements/all
List all available achievements with unlock status.

## Sync Endpoints

### POST /sync/push
Push local changes to server.

**Body:**
```json
{
  "records": [
    {
      "type": "Prompt",
      "id": "uuid",
      "data": {...},
      "modifiedAt": "2024-01-15T10:30:00Z"
    }
  ],
  "deletions": [
    {"type": "Prompt", "id": "uuid"}
  ]
}
```

**Response:**
```json
{
  "accepted": ["uuid1", "uuid2"],
  "conflicts": [
    {
      "id": "uuid",
      "serverModifiedAt": "2024-01-15T10:35:00Z",
      "serverData": {...}
    }
  ],
  "serverChangeToken": "token-string"
}
```

### GET /sync/pull
Pull remote changes.

**Query Parameters:**
- `since_token` (optional): Server change token for incremental sync

**Response:**
```json
{
  "changes": [
    {
      "type": "Prompt",
      "id": "uuid",
      "action": "update",
      "data": {...}
    }
  ],
  "deletions": [
    {"type": "Prompt", "id": "uuid"}
  ],
  "serverChangeToken": "new-token"
}
```

## Webhook Events

Register webhooks at: POST /webhooks

### Event Types

- `session.completed`: AI session finished
- `commit.pushed`: Git commit pushed
- `achievement.unlocked`: New achievement unlocked
- `project.synced`: Project data synced

### Webhook Payload

```json
{
  "event": "session.completed",
  "timestamp": "2024-01-15T10:35:00Z",
  "data": {
    "sessionId": "uuid",
    "projectName": "project-name",
    "provider": "claude_code",
    "tokensUsed": 7000
  }
}
```

## Rate Limits

- **Standard:** 100 requests per minute
- **Sync endpoints:** 10 requests per minute
- **Burst:** Up to 20 requests in 10 seconds

**Rate Limit Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1704067200
```

## Error Responses

### Error Format

```json
{
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Authentication token is invalid or expired",
    "details": {}
  }
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INVALID_TOKEN` | 401 | Invalid or expired token |
| `UNAUTHORIZED` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `RATE_LIMITED` | 429 | Too many requests |
| `VALIDATION_ERROR` | 400 | Invalid request data |
| `CONFLICT` | 409 | Sync conflict detected |
| `SERVER_ERROR` | 500 | Internal server error |

## SDK Usage

```swift
import ProjectStatsAPI

let client = WebAPIClient()
client.setAuthToken("your-jwt-token")

// Fetch projects
let projects = try await client.get("/projects", as: ProjectsResponse.self)

// Create prompt
let prompt = try await client.post("/prompts", body: NewPrompt(text: "..."))
```
