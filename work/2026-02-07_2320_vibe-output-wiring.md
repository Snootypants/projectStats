Work Log: VIBE Tab Output Wiring
Prompt Summary:
Wired terminal output from VIBE tab's planning, execution, and summarizer terminals
to their respective handlers. Added onOutputCallback to TerminalTabItem and created
VibeTerminalHostView to host a hidden shell process for the planning terminal.

Scopes Completed:
* [A] Hidden terminal for planning — done (VibeTerminalHostView + onOutputCallback + bridge wiring)
* [B] Execution terminal output — done (onOutputCallback on execution tab)
* [C] Summarizer ghost output — done (onOutputCallback on ghost tab)
* [D] End-to-end verification — done (clean build, flow traced)

Results:
* Commits: 3 (c0ebdc9, 12f8dfb, e0cca32)
* Files created: 1 (VibeTerminalHostView.swift)
* Files modified: 5 (TerminalTabsViewModel.swift, VibeTerminalBridge.swift, VibeSummarizerService.swift, VibeTabView.swift, project.pbxproj)
* Tests: Existing tests preserved + 4 new tests added (ServiceTests.swift). Test target not configured in Xcode scheme — tests exist as source files but cannot be run via xcodebuild.
* Build: pass (clean build)

Self-Grade: B+
The core fix is clean and minimal: one new property (onOutputCallback) on TerminalTabItem,
one new file (VibeTerminalHostView), and three 3-line callback wiring changes. The output
pipeline is now connected end-to-end. Deducted from A because: (1) test target is not
configured so tests can't actually run, and (2) could not verify runtime behavior without
launching the app. The architectural approach is sound — follows existing patterns exactly
(same MonitoringTerminalView pattern, same shell startup sequence, same onOutput callback
structure as TerminalSessionView).
