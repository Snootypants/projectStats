# Changelog

## Overview

This changelog is generated from git history. The project uses a prompt-based development workflow where each prompt represents a feature set or implementation batch.

---

## [Unreleased]

### Added
- Comprehensive documentation (Prompt 33)

### Changed
- None

### Fixed
- None

---

## Version History (from Git)

### Prompt 32 — Universal AI Harness + CloudKit Sync (21 commits)

Major feature release adding multi-provider AI support and CloudKit sync foundation.

**AI Provider System:**
- [Part A] Add AI Provider model with types, models, and configuration
- [Part B] Add AI Provider Registry service
- [Part C] Add Codex CLI integration service
- [Part D] Add Model Selector UI component
- [Part E] Add thinking level controls and service
- [Part F] Add terminal provider switching
- [Part G] Add session tracking per AI provider
- [Part H] Add provider performance metrics service
- [Part I] Add cost comparison dashboard card
- [Part J] Add AI Provider settings UI

**CloudKit Sync:**
- [Part K] Add CloudKit container setup
- [Part L] Add Syncable protocol for CloudKit
- [Part M] Add CKRecord mappers for syncable types
- [Part N] Add Sync Engine core
- [Part O] Add Conflict Resolution system
- [Part P] Add Offline Queue Manager
- [Part Q] Add Sync Status UI components
- [Part R] Add Sync Settings UI
- [Part S] Add Background Sync Scheduler
- [Part T] Add Web API Foundation

---

### Prompt 31 — The Monster (16 commits)

Extensive feature batch covering backup, security, voice, and more.

**Features:**
- [Part A] Add backup button to zip project for sharing
- [Part B] Add secrets scanning before commit with warning sheet
- [Part C] Add local branches Codex-style (copy folder + git branch)
- [Part D] Add global hotkey Cmd+Shift+F for Focus Mode
- [Part E] Add hourly plan usage snapshots to SwiftData
- [Part F] Add ccusage display settings UI
- [Part G] Add Voice Notes with Whisper STT
- [Part H] Add TTS Integration with OpenAI and ElevenLabs
- [Part I] Wire up CodeVectorDB with SQLite persistence
- [Part J] Add Export to Markdown functionality
- [Part K] Add Project Archive functionality
- [Part L] Add Session Summary functionality
- [Part M] Add DB Architecture v2 - New Models
- [Part N] Add DB Architecture v2 - Migration Service
- [Part O] Add DB Architecture v2 - Wire to UI
- [Part P] Settings Cleanup & Final Polish

---

### Prompt 30 — Claude Usage Tracking (7 commits)

Claude Code token usage via ccusage.

- [Part G] Add Claude usage tracking from ccusage
- [Part F] Fix Send button to execute prompt in terminal
- [Part E] Add tab visibility toggles to Settings
- [Part D] Add data cleanup to move diffs from prompts
- [Part C] Add Diffs tab and SavedDiff model
- [Part B] Redesign Prompts tab with horizontal tabs
- [Part A] Fix Prompts tab layout squeeze
- [Fix] Run ccusage process on background thread
- [Fix] Add 10-second timeout to ccusage process
- [Fix] Fix ccusage JSON parsing

---

### Prompt 29 — Time Tracking (6 commits)

Human vs AI time tracking system.

- [Part F] Migrate to UNUserNotificationCenter
- [Part E] Update TimeTrackingCard with human/AI breakdown
- [Part D] Add project time counter to workspace toolbar
- [Part C] Add Claude session detection to TerminalOutputMonitor
- [Part B] Rewrite TimeTrackingService with human/AI tracking
- [Part A] Add sessionType and aiModel fields to TimeEntry

---

### Prompt 28 — UI Polish (7 commits)

UI improvements and bug fixes.

- [Part G] Add Bar Opacity slider and smooth all sliders
- [Part F] Fix Settings sidebar styling
- [Part E] Polish Projects grid cards
- [Part D] Improve IDE tab bar active state visibility
- [Part C] Fix tab closing bug in TabManagerViewModel
- [Part B] Add work log import from /work/ folder
- [Part A] Add PromptImportService to import /prompts/*.md files

---

### Prompt 27 — Divider Glow & Settings Redesign (8 commits)

Visual polish and settings UI overhaul.

- Add divider glow controls to appearance settings
- Refactor divider glow to use @AppStorage for all settings
- Wire Prompts tab to display SavedPrompt from SwiftData
- Remove unused ColorExtensions.swift file
- Redesign settings window with sidebar navigation
- Add glowing panel dividers with hover effect

---

### Prompt 26 — Terminal & IDE Polish (10 commits)

Terminal functionality and IDE improvements.

- Fix terminal send to use [UInt8] instead of Data
- Fix send prompt to use correct PTY input method
- Add terminal polish, prompt capture, file editor
- Add XP progress bar and fix achievement tracking
- Fix terminal persistence across project tab switches
- Add achievements UI to Home tab
- Fix terminal command execution and UI update warnings
- Fix terminal hang and divider jitter
- Fix UI bugs and polish workspace experience

---

### Earlier Development

**Messaging & Remote Commands:**
- Add messaging and remote command system
- Telegram, Slack, Discord, ntfy providers

**Data Pipeline:**
- UI live updates from SwiftData
- Git log parsing for commit history
- Terminal monitor for git event detection
- CachedCommit model for history storage

**Tab Architecture:**
- Add Chrome-style tab bar
- TabModel and TabManagerViewModel
- ProjectPickerView for new tabs
- HomeView from existing dashboard
- TabShell as new root view
- Workspace tabs with IDEModeView

**Project Discovery:**
- JSON-first discovery from projectstats.json
- Scanner improvements and bug fixes
- Data pipeline sync to SwiftData

---

## Commit Count by Feature Area

| Area | Approximate Commits |
|------|---------------------|
| AI Provider System | 10 |
| CloudKit Sync | 10 |
| Time Tracking | 6 |
| Terminal/IDE | 15 |
| UI Polish | 12 |
| Data/Models | 10 |
| Notifications | 5 |
| Settings | 8 |
| Messaging | 5 |
| Tab System | 10 |
| Other | 9 |

**Total: ~100 commits**

---

## Development Timeline

Based on commit dates:
- Project start: Early January 2026
- Tab architecture: Late January 2026
- Major feature additions: Late January - Early February 2026
- Current documentation: February 4, 2026

---

## Notes

- Commits follow "[Part X]" pattern for multi-part features
- Bug fixes marked with "[Fix]"
- Documentation marked with "[Docs]"
- Most commits are atomic feature additions
- Work logs in `/work/` folder contain detailed session notes
