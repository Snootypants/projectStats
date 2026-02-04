# Data Models

## Overview

| Metric | Count |
|--------|-------|
| Total model files | 21 |
| SwiftData @Model classes | 16 |
| Plain structs | 12 |
| Database | SwiftData with CloudKit sync |

## SwiftData Schema

Models registered in `AppModelContainer`:
```swift
CachedProject, CachedDailyActivity, CachedPrompt, CachedWorkLog, CachedCommit,
ChatMessage, TimeEntry, AchievementUnlock, ProjectNote, SavedPrompt, SavedDiff,
ClaudeUsageSnapshot, ClaudePlanUsageSnapshot, ProjectSession, DailyMetric,
WorkItem, WeeklyGoal, AIProviderConfig, AISessionV2
```

---

## Project (Struct)

**File:** `Models/Project.swift`

**Purpose:** In-memory representation of a discovered code project

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| path | URL | File system path |
| name | String | Project name |
| description | String? | Project description |
| githubURL | String? | GitHub repository URL |
| language | String? | Primary language |
| lineCount | Int | Total lines of code |
| fileCount | Int | Number of source files |
| promptCount | Int | Number of prompts |
| workLogCount | Int | Number of work logs |
| lastCommit | Commit? | Most recent commit |
| lastScanned | Date | Last scan timestamp |
| githubStats | GitHubStats? | GitHub API stats |
| gitMetrics | ProjectGitMetrics? | Git activity metrics |
| gitRepoInfo | GitRepoInfo? | Git repository info |
| jsonStatus | String? | Status from projectstats.json |
| techStack | [String] | Technologies used |
| languageBreakdown | [String: Int] | Lines per language |
| structure | String? | Project structure type |
| structureNotes | String? | Notes about structure |
| sourceDirectories | [String] | Source directories |
| excludedDirectories | [String] | Excluded directories |
| firstCommitDate | Date? | First commit date |
| totalCommits | Int? | Total commit count |
| branches | [String] | Git branches |
| currentBranch | String? | Current branch name |

**Computed Properties:**
- `status: ProjectStatus` — Calculated from jsonStatus or lastCommit date
- `countsTowardTotals: Bool` — Whether to include in aggregate stats
- `formattedLineCount: String` — Human-readable line count (e.g., "1.2k")
- `lastActivityString: String` — Relative time since last commit

---

## ProjectStatus (Enum)

**File:** `Models/Project.swift`

**Purpose:** Project activity status

**Cases:**
| Case | Color | Counts in Totals |
|------|-------|------------------|
| active | green | Yes |
| inProgress | yellow | Yes |
| dormant | gray | Yes |
| paused | yellow | Yes |
| experimental | blue | Yes |
| archived | gray | No |
| abandoned | gray | No |

---

## CachedProject (@Model)

**File:** `Models/CachedModels.swift`

**Purpose:** SwiftData persistence of Project data

**Properties:**
| Property | Type | Description |
|----------|------|-------------|
| path | String | File system path (primary key) |
| name | String | Project name |
| descriptionText | String? | Description |
| githubURL | String? | GitHub URL |
| language | String? | Primary language |
| lineCount | Int | Lines of code |
| fileCount | Int | File count |
| promptCount | Int | Prompt count |
| workLogCount | Int | Work log count |
| lastCommitHash | String? | Last commit SHA |
| lastCommitMessage | String? | Last commit message |
| lastCommitAuthor | String? | Last commit author |
| lastCommitDate | Date? | Last commit date |
| lastScanned | Date | Last scan time |
| jsonStatus | String? | Status from JSON |
| techStackData | Data? | JSON-encoded [String] |
| languageBreakdownData | Data? | JSON-encoded [String: Int] |
| structure | String? | Project structure |
| structureNotes | String? | Structure notes |
| sourceDirectoriesData | Data? | JSON-encoded [String] |
| excludedDirectoriesData | Data? | JSON-encoded [String] |
| firstCommitDate | Date? | First commit |
| totalCommits | Int? | Commit count |
| branchesData | Data? | JSON-encoded [String] |
| currentBranch | String? | Current branch |
| statsGeneratedAt | Date? | Stats generation time |
| statsSource | String? | "json" or "scanner" |
| isArchived | Bool | User archive flag |
| archivedAt | Date? | Archive timestamp |

**Methods:**
- `toProject() -> Project` — Convert to in-memory struct
- `update(from project: Project)` — Update from in-memory struct

---

## CachedPrompt (@Model)

**File:** `Models/CachedModels.swift`

**Purpose:** Cached prompt files from /prompts/ directory

| Property | Type | Description |
|----------|------|-------------|
| projectPath | String | Parent project path |
| promptNumber | Int | Prompt number (1, 2, 3...) |
| filename | String | Filename (e.g., "1.md") |
| content | String | Full markdown content |
| contentHash | String | SHA256 for change detection |
| fileModified | Date | File modification date |
| cachedAt | Date | Cache timestamp |

---

## CachedWorkLog (@Model)

**File:** `Models/CachedModels.swift`

**Purpose:** Cached work log files from /work/ directory

| Property | Type | Description |
|----------|------|-------------|
| projectPath | String | Parent project path |
| filename | String | Work log filename |
| content | String | Markdown content |
| contentHash | String | SHA256 hash |
| fileModified | Date | File modification date |
| cachedAt | Date | Cache timestamp |
| isStatsFile | Bool | From /work/stats/ |
| sourceFile | String? | Original filename |
| started | Date? | Session start (stats only) |
| ended | Date? | Session end (stats only) |
| linesAdded | Int? | Lines added |
| linesDeleted | Int? | Lines deleted |
| commitHash | String? | Associated commit |
| summary | String? | Description text |

---

## CachedCommit (@Model)

**File:** `Models/CachedModels.swift`

**Purpose:** Cached git commits

| Property | Type | Description |
|----------|------|-------------|
| projectPath | String | Project path |
| commitHash | String? | Full SHA |
| shortHash | String | Short SHA |
| message | String | Commit message |
| author | String | Author name |
| authorEmail | String? | Author email |
| date | Date | Commit date |
| linesAdded | Int | Lines added |
| linesDeleted | Int | Lines deleted |
| filesChanged | Int | Files changed |

---

## SavedPrompt (@Model)

**File:** `Models/SavedPrompt.swift`

**Purpose:** User-saved prompts (synced via CloudKit)

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| projectPath | String | Associated project |
| title | String | Prompt title |
| content | String | Prompt content |
| createdAt | Date | Creation date |
| updatedAt | Date | Last update |
| tags | Data? | JSON-encoded [String] |

**CloudKit:**
- Record type: `"SavedPrompt"`
- Synced fields: id, projectPath, title, content, createdAt, updatedAt, tags

---

## SavedDiff (@Model)

**File:** `Models/SavedDiff.swift`

**Purpose:** User-saved diffs/patches (synced via CloudKit)

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| projectPath | String | Associated project |
| title | String | Diff title |
| diffContent | String | Patch content |
| commitMessage | String? | Associated commit |
| createdAt | Date | Creation date |

**CloudKit:**
- Record type: `"SavedDiff"`
- Synced fields: id, projectPath, title, diffContent, commitMessage, createdAt

---

## TimeEntry (@Model)

**File:** `Models/TimeEntry.swift`

**Purpose:** Time tracking entries (synced via CloudKit)

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| projectPath | String | Project path |
| startTime | Date | Session start |
| endTime | Date? | Session end |
| durationMinutes | Int | Duration in minutes |
| sessionType | String | "human" or "ai" |
| aiType | String? | AI provider (if AI session) |
| aiModel | String? | Model used |
| notes | String? | Session notes |

**CloudKit:**
- Record type: `"TimeEntry"`
- Synced: Yes

---

## AIProviderType (Enum)

**File:** `Models/AIProvider.swift`

**Purpose:** Types of AI providers

| Case | Display Name | CLI Tool? | Requires API Key? |
|------|--------------|-----------|-------------------|
| claudeCode | Claude Code | Yes | No (OAuth) |
| codex | Codex | Yes | No (OAuth) |
| anthropicAPI | Anthropic API | No | Yes |
| openaiAPI | OpenAI API | No | Yes |
| ollama | Ollama | No | No (local) |
| custom | Custom | No | Yes |

---

## AIModel (Enum)

**File:** `Models/AIProvider.swift`

**Purpose:** Available AI models with pricing

**Claude Models:**
| Model | Input/1M | Output/1M |
|-------|----------|-----------|
| claude-opus-4-5 | $5.00 | $25.00 |
| claude-sonnet-4-5 | $3.00 | $15.00 |
| claude-haiku-4-5 | $1.00 | $5.00 |
| claude-opus-4 | $15.00 | $75.00 |
| claude-sonnet-4 | $3.00 | $15.00 |
| claude-sonnet-3-5 | $3.00 | $15.00 |
| claude-haiku-3 | $0.25 | $1.25 |

**OpenAI Models:**
| Model | Input/1M | Output/1M |
|-------|----------|-----------|
| gpt-4o | $2.50 | $10.00 |
| gpt-4o-mini | $0.15 | $0.60 |
| gpt-4.1 | $2.00 | $8.00 |
| o3 | $10.00 | $40.00 |
| o4-mini | $1.10 | $4.40 |

**Local Models (free):**
- llama3.2, codellama, deepseek-coder, qwen2.5-coder

---

## ThinkingLevel (Enum)

**File:** `Models/AIProvider.swift`

**Purpose:** Extended thinking budget levels

| Level | Budget Tokens | Description |
|-------|---------------|-------------|
| none | 0 | Fast responses |
| low | 1024 | Light reasoning |
| medium | 4096 | Moderate analysis |
| high | 16384 | Deep thinking |

---

## AIProviderConfig (@Model)

**File:** `Models/AIProvider.swift`

**Purpose:** Persistent AI provider configuration

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| providerType | String | AIProviderType raw value |
| displayName | String | User-visible name |
| isEnabled | Bool | Provider enabled |
| isDefault | Bool | Default provider |
| apiKey | String? | API key (if needed) |
| baseURL | String? | Custom base URL |
| defaultModelRaw | String? | Default model |
| defaultThinkingLevelRaw | String? | Default thinking level |
| createdAt | Date | Creation date |
| updatedAt | Date | Last update |
| ollamaHost | String? | Ollama host |
| ollamaPort | Int? | Ollama port |

---

## AISessionV2 (@Model)

**File:** `Models/AIProvider.swift`

**Purpose:** Enhanced AI session tracking (synced via CloudKit)

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| providerType | String | Provider type |
| modelRaw | String | Model identifier |
| thinkingLevelRaw | String? | Thinking level |
| projectPath | String? | Associated project |
| startTime | Date | Session start |
| endTime | Date? | Session end |
| inputTokens | Int | Input tokens used |
| outputTokens | Int | Output tokens |
| thinkingTokens | Int | Thinking tokens |
| cacheReadTokens | Int | Cache read tokens |
| cacheWriteTokens | Int | Cache write tokens |
| costUSD | Double | Calculated cost |
| wasSuccessful | Bool | Completion status |
| errorMessage | String? | Error if failed |

---

## Achievement (Enum)

**File:** `Models/Achievement.swift`

**Purpose:** Achievement definitions

**22 Achievements across categories:**

**Commits:**
- firstBlood — First commit of the day (25 XP)
- centurion — 100 commits in a month (50 XP)
- prolific — 1000 total commits (100 XP)

**Streaks:**
- weekWarrior — 7 day coding streak (25 XP)
- monthlyMaster — 30 day coding streak (100 XP)
- streakSurvivor — Recovered from broken streak (200 XP)

**Time:**
- nightOwl — Coded past midnight 5 times (25 XP)
- earlyBird — Coded before 6am 5 times (25 XP)
- marathoner — 8+ hours in one day (50 XP)
- sprinter — Ship a feature in under 1 hour (50 XP)

**Lines:**
- novelist — Write 10,000 lines in a week (50 XP)
- minimalist — Delete more than you add in a week (50 XP)
- refactorer — Refactor 1,000+ lines (100 XP)

**Projects:**
- multiTasker — Work on 5 projects in one day (100 XP)
- focused — Work on 1 project for a week straight (100 XP)
- launcher — Complete a project (200 XP)

**Claude:**
- aiWhisperer — 100 Claude sessions (100 XP)
- contextMaster — Hit 90% context without errors (100 XP)
- promptEngineer — Create 50 prompts (25 XP)

**Social:**
- shipper — Push to production on Friday (50 XP)
- collaborator — Generate a report for someone (50 XP)

**Monetization:**
- proSupporter — Subscribed to Pro (200 XP)

---

## AchievementUnlock (@Model)

**File:** `Models/Achievement.swift`

**Purpose:** Record of unlocked achievements

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| key | String | Achievement raw value |
| unlockedAt | Date | Unlock timestamp |
| projectPath | String? | Associated project |

---

## ClaudeUsageSnapshot (@Model)

**File:** `Models/ClaudeUsageSnapshot.swift`

**Purpose:** Token usage snapshot from ccusage

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| capturedAt | Date | Capture timestamp |
| inputTokens | Int | Input tokens |
| outputTokens | Int | Output tokens |
| cacheCreationTokens | Int | Cache creation |
| cacheReadTokens | Int | Cache read |
| totalCost | Double | Total cost USD |
| projectPath | String? | Project (if scoped) |

---

## ClaudePlanUsageSnapshot (@Model)

**File:** `Models/ClaudePlanUsageSnapshot.swift`

**Purpose:** Plan usage snapshot from Anthropic OAuth API

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| capturedAt | Date | Capture timestamp |
| fiveHourUtilization | Double | 5h window usage (0-1) |
| fiveHourResetsAt | Date? | 5h reset time |
| sevenDayUtilization | Double | 7d window usage (0-1) |
| sevenDayResetsAt | Date? | 7d reset time |
| opusUtilization | Double? | Opus-specific usage |
| opusResetsAt | Date? | Opus reset time |
| sonnetUtilization | Double? | Sonnet-specific usage |
| sonnetResetsAt | Date? | Sonnet reset time |

---

## ProjectSession (@Model)

**File:** `Models/DBv2Models.swift`

**Purpose:** Coding session within a project (DB v2)

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| projectPath | String | Project path |
| startTime | Date | Session start |
| endTime | Date? | Session end |
| duration | TimeInterval | Duration seconds |
| commitsMade | Int | Commits in session |
| filesModified | Int | Files modified |
| linesAdded | Int | Lines added |
| linesRemoved | Int | Lines removed |
| claudeTokensUsed | Int | Claude tokens |
| notes | String? | Session notes |

---

## DailyMetric (@Model)

**File:** `Models/DBv2Models.swift`

**Purpose:** Aggregated daily metrics for fast loading

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| date | Date | Day (start of day) |
| projectPath | String? | Project (nil = global) |
| totalCommits | Int | Commits |
| totalTimeMinutes | Int | Time in minutes |
| totalLinesAdded | Int | Lines added |
| totalLinesRemoved | Int | Lines removed |
| totalClaudeTokens | Int | Claude tokens |
| totalClaudeCost | Double | Cost USD |
| sessionsCount | Int | Session count |
| uniqueFilesModified | Int | Files modified |

---

## WorkItem (@Model)

**File:** `Models/DBv2Models.swift`

**Purpose:** Task/bug/feature tracking

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| projectPath | String | Project path |
| title | String | Item title |
| descriptionText | String? | Description |
| itemType | String | "task", "bug", "feature", "improvement" |
| status | String | "todo", "in_progress", "done", "blocked" |
| priority | Int | 1-5 (1 = highest) |
| createdAt | Date | Creation date |
| updatedAt | Date | Last update |
| completedAt | Date? | Completion date |
| estimatedMinutes | Int? | Time estimate |
| actualMinutes | Int? | Actual time |
| linkedCommitHashes | Data? | JSON [String] |
| tags | Data? | JSON [String] |

---

## WeeklyGoal (@Model)

**File:** `Models/DBv2Models.swift`

**Purpose:** Weekly goal tracking

| Property | Type | Description |
|----------|------|-------------|
| id | UUID | Unique identifier |
| weekStartDate | Date | Week start |
| projectPath | String? | Project (nil = global) |
| goalText | String | Goal description |
| targetCommits | Int? | Target commits |
| targetHours | Int? | Target hours |
| actualCommits | Int | Actual commits |
| actualMinutes | Int | Actual minutes |
| isCompleted | Bool | Completion flag |
| reflectionNotes | String? | Reflection |

---

## Commit (Struct)

**File:** `Models/Commit.swift`

**Purpose:** Git commit representation

| Property | Type | Description |
|----------|------|-------------|
| id | String | Commit SHA |
| message | String | Commit message |
| author | String | Author name |
| date | Date | Commit date |
| linesAdded | Int | Lines added |
| linesRemoved | Int | Lines removed |

**Methods:**
- `static fromGitLog(_ line: String) -> Commit?` — Parse from git log format

---

## ActivityStats (Struct)

**File:** `Models/ActivityStats.swift`

**Purpose:** Daily activity aggregation

| Property | Type | Description |
|----------|------|-------------|
| date | Date | Day |
| commits | Int | Commit count |
| linesAdded | Int | Lines added |
| linesRemoved | Int | Lines removed |
| projectPaths | [String] | Active projects |

---

## GitRepoInfo (Struct)

**File:** `Models/GitRepoInfo.swift`

**Purpose:** Git repository metadata

| Property | Type | Description |
|----------|------|-------------|
| currentBranch | String? | Current branch |
| defaultBranch | String? | Default branch |
| remoteName | String? | Remote name |
| remoteURL | String? | Remote URL |
| totalCommits | Int | Total commits |
| firstCommitDate | Date? | First commit |
| lastCommitDate | Date? | Last commit |

---

## SecretMatch (Struct)

**File:** `Models/SecretMatch.swift`

**Purpose:** Secret detection result

| Property | Type | Description |
|----------|------|-------------|
| file | String | File path |
| line | Int | Line number |
| secretType | String | Type of secret |
| match | String | Matched pattern |
