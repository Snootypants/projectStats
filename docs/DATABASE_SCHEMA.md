# Database Schema

ProjectStats uses SwiftData for local persistence. This document describes the data models.

## TimeEntry

Tracks time spent working on projects, distinguishing between human and AI-assisted work.

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `projectPath` | String | Absolute path to the project directory |
| `startTime` | Date | When the session started |
| `endTime` | Date | When the session ended |
| `duration` | TimeInterval | Calculated duration in seconds |
| `isManual` | Bool | Whether this entry was manually created |
| `notes` | String? | Optional notes about the session |
| `sessionType` | String | Type of session: "human", "claude_code", "codex", "api" |
| `aiModel` | String? | AI model used (e.g., "opus-4", "sonnet-4") - only for AI sessions |
| `tokensUsed` | Int? | Token count if available from terminal parsing |

### Session Types

- **human**: Direct human coding/editing time
- **claude_code**: Time while Claude Code CLI is actively running
- **codex**: Time while OpenAI Codex/ChatGPT is active
- **api**: Time while using other AI APIs

### Usage Notes

- Human sessions are tracked when a project workspace tab is active
- AI sessions are detected via terminal output monitoring (e.g., Claude's "Cooked for" message)
- Idle detection pauses human tracking after 5 minutes of inactivity
- System-wide idle time is checked via IOKit for accurate detection

## Other Models

See `projectStats/Models/` for other SwiftData models:

- `CachedProject` - Project metadata cache
- `CachedDailyActivity` - Daily activity aggregations
- `CachedPrompt` - Imported prompts from /prompts folders
- `CachedWorkLog` - Work logs from /work folders
- `CachedCommit` - Git commit history
- `ChatMessage` - AI chat history
- `AchievementUnlock` - Unlocked achievements
- `ProjectNote` - Notes attached to projects
- `SavedPrompt` - User-saved prompt templates
