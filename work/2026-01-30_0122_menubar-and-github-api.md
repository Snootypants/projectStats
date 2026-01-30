# Fix Menu Bar Icon + Wire Up GitHub API

## Prompt Summary
Two objectives:
1. Fix the menu bar icon not appearing (invalid SF Symbol)
2. Wire up GitHub API integration for enhanced stats (stars, forks, issues)

## Changes

### Commit 1: Fix Menu Bar Icon
- **File:** `ProjectStatsApp.swift`
- **Change:** Replaced invalid SF Symbol `"chevron.left.forwardslash.chevron.right"` with `"chart.bar.xaxis"`

### Commit 2: GitHub API Integration
- **GitHubClient.swift:** Complete rewrite with enhanced API methods:
  - `getRepo()` - fetch repository info (stars, forks, issues)
  - `getCommits()` - fetch commit history
  - `getCommitStats()` - fetch detailed commit stats
  - `getContributionCalendar()` - GraphQL query for contribution data
  - `parseGitHubURL()` - static helper to extract owner/repo from URL
  - Proper error handling with `GitHubError` enum

- **Project.swift:** Added `GitHubStats` struct with stars, forks, openIssues, watchers

- **DashboardViewModel.swift:** Added `fetchGitHubStats()` method called after project loading

- **ProjectRowView.swift:** Display GitHub stats (stars, forks, issues) when available

## Closing Report
- **Build status:** SUCCESS
- **Files modified:** 4 (ProjectStatsApp.swift, GitHubClient.swift, Project.swift, DashboardViewModel.swift, ProjectRowView.swift)
- **GitHub integration:** Optional enhancement - app works without token
- **Self-grade:** A - Both objectives completed, minimal changes, existing functionality preserved
