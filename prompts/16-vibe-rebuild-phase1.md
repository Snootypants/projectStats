# Prompt 16: VIBE Tab — Complete Rebuild Phase 1
# Headless Claude Code + JSON Stream Chat UI

## MISSION

Gut the existing VIBE tab completely and rebuild it from scratch. The new VIBE tab launches Claude Code as a headless subprocess with `--output-format stream-json`, parses the real-time JSON event stream, and renders it as a clean native chat interface. No terminal emulator. No SwiftTerm. No hidden views. Just a Swift `Process`, JSON parsing, and SwiftUI chat bubbles.

## META OUTPUT INSTRUCTIONS (NON-NEGOTIABLE)

You must follow this 4-part response structure for the overall task:

1. **Plan:** Outline moves in order. State what you will NOT touch.
2. **Difficulty:** Brief estimate and likely failure points.
3. **Execute:** Do the work with strict discipline. Minimal edits. One scope at a time.
4. **Report + Self-Grade:** What changed, why, grade yourself (A–F). Be brutally honest.

## ENGINEERING PHILOSOPHY (NON-NEGOTIABLE)

- Write the simplest, most direct solution possible. Less code is better code.
- Do not over-engineer. Do not add abstractions unless explicitly needed.
- If there's a 10-line solution and a 40-line solution, write the 10-line solution.
- Clever code is bad code. Readable code is good code.
- TDD is mandatory. Write tests FIRST for every scope. Tests are cheap insurance.

## PROCESS RULES (NON-NEGOTIABLE)

- Follow existing patterns in the codebase. Do not reinvent.
- All existing tests must continue to pass.
- Commit after completing EACH scope. Do not batch.
- Build must pass before moving to the next scope.
- If stuck on a scope for >10 minutes, add a TODO comment and move on.

## COMMIT DISCIPLINE (NON-NEGOTIABLE)

After EACH scope:
```bash
git add -A && git commit -m "SCOPE_LETTER - description"
```

After ALL scopes complete:
```bash
git push origin main
```

## CONTEXT

### What we're replacing

The current VIBE tab attempted to use a hidden `LocalProcessTerminalView` (SwiftTerm NSView) to run Claude Code, then scrape the terminal output and render it as chat. This approach has failed across multiple prompts because:

1. Hidden NSViews with zero dimensions cause SwiftTerm to buffer incorrectly (one-char-per-line)
2. Raw ANSI escape codes leak through and pollute the chat
3. Tab switching destroys/recreates NSViews, losing all state
4. Parsing unstructured terminal scroll output is fundamentally fragile

### The new approach

Claude Code supports `--output-format stream-json` which outputs NDJSON (one JSON object per line) in real-time. This gives us structured, typed events:

- `system` — init message with session info
- `assistant` — Claude's responses with text content AND tool_use blocks
- `user` — user messages
- `result` — final stats (cost, duration, turns, session_id)

Tool use blocks contain: tool name (Bash, Read, Write, Edit, etc.), input parameters, and results. Every piece of data is structured and labeled.

We also have `--input-format stream-json` for sending messages IN as JSONL through stdin. So communication is fully bidirectional and structured.

### The claude binary

The `claude` binary location may vary. Check these in order:
1. `which claude` — might be on PATH
2. `~/.npm-global/bin/claude`
3. `/usr/local/bin/claude`
4. `~/.local/bin/claude`

Use `Process` to run `which claude` at startup and cache the path. If not found, show a setup prompt in the VIBE tab.

### Permission Modes

The VIBE tab needs a mode selector BEFORE starting a session:

**Flavor (YOLO):** Launches with `--dangerously-skip-permissions`. No approval prompts. Tool calls stream by as informational cards only. Fast, autonomous, no interruptions.

**Sans Flavor (Normal):** Launches without the permissions flag. Claude Code will emit permission request events in the JSON stream when it wants to run a command, write a file, etc. The chat UI must render these as interactive approval cards with Allow / Deny buttons. The user's response gets sent back through stdin.

### Files to DELETE (gut the old approach)

- `VibeTerminalBridge.swift`
- `VibeProcessBridge.swift`
- `VibeSummarizerService.swift`

Keep `VibeTabView.swift` as the entry point but gut its contents completely.

### Files to NOT touch

- Everything in `Views/IDE/`
- `TerminalTabItem.swift`, `TerminalTabView.swift`
- Achievement/XP system
- All SwiftData models not related to VIBE
- `TabManagerViewModel`, `TabShellView`, `TabBarView`
- Settings, preferences, scanner, dashboard
- The entire data pipeline

## SCOPES

### SCOPE A — Claude Code Process Manager
New files: `Services/Claude/ClaudeProcessManager.swift`, `Models/Claude/ClaudeEvent.swift`

### SCOPE B — Chat Data Model
New file: `Models/Claude/ChatMessage.swift`

### SCOPE C — Chat ViewModel
New file: `ViewModels/VibeChatViewModel.swift`

### SCOPE D — Chat UI
Rebuild `Views/Vibe/VibeTabView.swift` + new component files

### SCOPE E — Wire Into Tab System
Minor wiring changes

### SCOPE F — Conversation Persistence
New files: `Services/Claude/ConversationStore.swift`, `Models/Claude/ConversationSession.swift`
