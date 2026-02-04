# Achievements

## Overview

ProjectStats includes a gamification system with 22 achievements across 7 categories.

| Metric | Value |
|--------|-------|
| Total achievements | 22 |
| Categories | 7 |
| XP per level | 250 |
| Max common XP | 25 |
| Max legendary XP | 200 |

---

## Achievement List

### Commits (3)

| Key | Name | Description | XP | Rarity | Condition |
|-----|------|-------------|----|----|-----------|
| `first_blood` | First Blood | First commit of the day | 25 | Common | Make the first commit on any given day |
| `centurion` | Centurion | 100 commits in a month | 50 | Rare | Reach 100 commits within a calendar month |
| `prolific` | Prolific | 1000 total commits | 100 | Epic | Accumulate 1000 lifetime commits |

### Streaks (3)

| Key | Name | Description | XP | Rarity | Condition |
|-----|------|-------------|----|----|-----------|
| `week_warrior` | Week Warrior | 7 day coding streak | 25 | Common | Commit every day for 7 consecutive days |
| `monthly_master` | Monthly Master | 30 day coding streak | 100 | Epic | Commit every day for 30 consecutive days |
| `streak_survivor` | Streak Survivor | Recovered from a broken streak | 200 | Legendary | Break a streak then rebuild it |

### Time (4)

| Key | Name | Description | XP | Rarity | Condition |
|-----|------|-------------|----|----|-----------|
| `night_owl` | Night Owl | Coded past midnight 5 times | 25 | Common | Make commits between 12am-5am, 5 times |
| `early_bird` | Early Bird | Coded before 6am 5 times | 25 | Common | Make commits between 4am-6am, 5 times |
| `marathoner` | Marathoner | 8+ hours in one day | 50 | Rare | Log 8+ hours of coding time in a single day |
| `sprinter` | Sprinter | Ship a feature in under 1 hour | 50 | Rare | Complete a feature quickly |

### Lines (3)

| Key | Name | Description | XP | Rarity | Condition |
|-----|------|-------------|----|----|-----------|
| `novelist` | Novelist | Write 10,000 lines in a week | 50 | Rare | Add 10,000 lines of code in 7 days |
| `minimalist` | Minimalist | Delete more than you add in a week | 50 | Rare | Net negative line count for a week |
| `refactorer` | Refactorer | Refactor 1,000+ lines | 100 | Epic | Delete 1,000 lines while adding similar |

### Projects (3)

| Key | Name | Description | XP | Rarity | Condition |
|-----|------|-------------|----|----|-----------|
| `multi_tasker` | Multi-Tasker | Work on 5 projects in one day | 100 | Epic | Make commits in 5 different projects |
| `focused` | Focused | Work on 1 project for a week straight | 100 | Epic | Only commit to one project for 7 days |
| `launcher` | Launcher | Complete a project | 200 | Legendary | Mark a project as completed |

### Claude (3)

| Key | Name | Description | XP | Rarity | Condition |
|-----|------|-------------|----|----|-----------|
| `ai_whisperer` | AI Whisperer | 100 Claude sessions | 100 | Epic | Complete 100 Claude Code sessions |
| `context_master` | Context Master | Hit 90% context without errors | 100 | Epic | Reach 90% context usage cleanly |
| `prompt_engineer` | Prompt Engineer | Create 50 prompts | 25 | Common | Save 50 prompts in the app |

### Social (2)

| Key | Name | Description | XP | Rarity | Condition |
|-----|------|-------------|----|----|-----------|
| `shipper` | Shipper | Push to production on Friday | 50 | Rare | Git push on a Friday |
| `collaborator` | Collaborator | Generate a report for someone | 50 | Rare | Use the report generation feature |

### Monetization (1)

| Key | Name | Description | XP | Rarity | Condition |
|-----|------|-------------|----|----|-----------|
| `pro_supporter` | Pro Supporter | Subscribed to Pro | 200 | Legendary | Subscribe to Pro tier |

---

## Rarity System

| Rarity | XP | Color |
|--------|----|----|
| Common | 25 | Gray |
| Rare | 50 | Blue |
| Epic | 100 | Purple |
| Legendary | 200 | Gold |

---

## XP and Leveling

```swift
// XP calculation
var totalXP: Int {
    unlockedAchievements.reduce(0) { $0 + $1.points }
}

// Level calculation (250 XP per level)
var currentLevel: Int {
    (totalXP / 250) + 1
}

// Progress within current level
var xpInCurrentLevel: Int {
    totalXP % 250
}
```

---

## Unlock Logic

**Service:** `AchievementService.swift`

### Core Methods

```swift
// Check and unlock (idempotent)
func checkAndUnlock(_ achievement: Achievement, projectPath: String? = nil) {
    guard !unlockedAchievements.contains(achievement) else { return }

    unlockedAchievements.insert(achievement)
    recentlyUnlocked = achievement

    // Persist to SwiftData
    let unlock = AchievementUnlock(key: achievement.rawValue, projectPath: projectPath)
    context.insert(unlock)

    // Report to Game Center
    reportToGameCenter(achievement)

    // Notify if enabled
    if SettingsViewModel.shared.notifyAchievementUnlocked {
        NotificationService.shared.sendNotification(
            title: "Achievement Unlocked",
            message: "\(achievement.title) — \(achievement.description)"
        )
    }
}
```

### Trigger Points

**On Git Push Detected:**
```swift
func onGitPushDetected(projectPath: String) {
    checkFirstCommitOfDay(projectPath: projectPath)
    checkTimeBasedAchievements(projectPath: projectPath)
    checkFridayDeploy(projectPath: projectPath)
    checkCommitCountAchievements(projectPath: projectPath)
}
```

**First Commit of Day:**
```swift
func checkFirstCommitOfDay(projectPath: String) {
    let todayString = formatDate(Date())
    if lastCommitDateString != todayString {
        lastCommitDateString = todayString
        checkAndUnlock(.firstBlood, projectPath: projectPath)
    }
}
```

**Time-Based:**
```swift
func checkTimeBasedAchievements(projectPath: String) {
    let hour = Calendar.current.component(.hour, from: Date())

    // Night Owl: 12am - 5am
    if hour >= 0 && hour < 5 {
        nightOwlCount += 1
        if nightOwlCount >= 5 {
            checkAndUnlock(.nightOwl, projectPath: projectPath)
        }
    }

    // Early Bird: 4am - 6am
    if hour >= 4 && hour < 6 {
        earlyBirdCount += 1
        if earlyBirdCount >= 5 {
            checkAndUnlock(.earlyBird, projectPath: projectPath)
        }
    }
}
```

**Friday Deploy:**
```swift
func checkFridayDeploy(projectPath: String) {
    let weekday = Calendar.current.component(.weekday, from: Date())
    if weekday == 6 {  // Friday
        checkAndUnlock(.shipper, projectPath: projectPath)
    }
}
```

**Commit Counts:**
```swift
func checkCommitCountAchievements(projectPath: String) {
    let totalCommits = GitService.shared.getCommitCount(at: path)

    if totalCommits >= 1000 {
        checkAndUnlock(.prolific, projectPath: projectPath)
    }

    let monthlyCommits = GitService.shared.getCommitCount(at: path, since: startOfMonth)
    if monthlyCommits >= 100 {
        checkAndUnlock(.centurion, projectPath: projectPath)
    }
}
```

---

## Game Center Integration

```swift
#if canImport(GameKit)
private func reportToGameCenter(_ achievement: Achievement) {
    let gcAchievement = GKAchievement(identifier: achievement.rawValue)
    gcAchievement.percentComplete = 100
    gcAchievement.showsCompletionBanner = true
    GKAchievement.report([gcAchievement])
}
#endif
```

---

## UI Components

### XPProgressBar

Located in `TabShellView.swift`:
```swift
struct XPProgressBar: View {
    // Shows: progress bar, XP count, level badge
    // Located below tab bar
}
```

### AchievementsDashboard

Located in `Views/Achievements/AchievementsDashboard.swift`:
- Grid of all achievements
- Locked/unlocked states
- Progress indicators
- Category filters

### AchievementBanner

Located in `Views/Achievements/AchievementBanner.swift`:
- Toast notification when achievement unlocked
- Shows icon, name, XP earned

### ShareCardView

Located in `Views/Achievements/ShareCardView.swift`:
- Generate shareable achievement card image
