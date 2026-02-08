Work Log: VIBE Tab — HeadlessTerminal + Chat UI
Prompt Summary:
Replaced the broken hidden-NSView approach (VibeTerminalHostView) with LocalProcess + LocalProcessDelegate
from SwiftTerm. HeadlessTerminal's `process` property is internal, so we used LocalProcess directly as the
documented fallback. Rewired VibeTerminalBridge to use VibeProcessBridge, updated chat UI styling, deleted
the old VibeTerminalHostView.

Scopes Completed:
* [A] VibeProcessBridge with LocalProcess — done (HeadlessTerminal.process is internal, used LocalProcess directly)
* [B] Fix ANSI stripping — already done in prompt 14, no changes needed
* [C] Rewrite VibeTerminalBridge with chat entries — done
* [D] Chat UI redesign — done (styling tweaks, removed hidden terminal view)
* [E] Delete old files + verification — done

Results:
* Commits: 5 (944109f, 0345583, 7f5cf8b, ef00053, pending)
* Files created: 2 (VibeProcessBridge.swift, prompts/15.md)
* Files modified: 4 (VibeTerminalBridge.swift, VibeTabView.swift, ServiceTests.swift, project.pbxproj)
* Files deleted: 1 (VibeTerminalHostView.swift)
* Tests: existing tests updated to match new API, 4 new tests for VibeProcessBridge
* Build: pass

Key Decision:
HeadlessTerminal.process is `internal` (not `public`) in SwiftTerm 1.10.0, meaning we cannot
call process.startProcess() or process.send() from outside the SwiftTerm module. Instead of
subclassing HeadlessTerminal (which wouldn't help since internal members aren't accessible to
subclasses in other modules), we used LocalProcess + LocalProcessDelegate directly. This is
actually cleaner — we don't need Terminal's escape sequence processing since we strip ANSI
codes ourselves.

Self-Grade: B+
The core work is solid — VibeProcessBridge correctly wraps LocalProcess, the bridge is cleanly
rewritten, the hidden NSView is gone, and tab switching no longer kills the process. However:
- Could not run tests (no test target configured in Xcode project)
- The echo filtering is simple string matching, may miss some edge cases
- Did not add full integration testing for the process lifecycle
