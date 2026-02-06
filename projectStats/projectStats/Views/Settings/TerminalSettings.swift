import SwiftUI

struct TerminalSettingsView: View {
    @ObservedObject var viewModel = SettingsViewModel.shared

    // Claude models available for terminal buttons
    private let claudeModels: [(id: String, display: String)] = [
        ("claude-opus-4-6", "Claude Opus 4.6"),
        ("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"),
        ("claude-haiku-4-5-20251001", "Claude Haiku 4.5"),
        ("claude-opus-4-20250514", "Claude Opus 4"),
        ("claude-sonnet-4-20250514", "Claude Sonnet 4"),
        ("claude-haiku-4-20250514", "Claude Haiku 4"),
    ]

    // Codex model options
    private let codexModels: [(id: String, display: String)] = [
        ("codex", "Default"),
        ("claude-opus-4-6", "Claude Opus 4.6"),
        ("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"),
    ]

    var body: some View {
        Form {
            Section("Terminal Buttons") {
                Text("Configure which AI buttons appear above the terminal and which models they use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Claude Button") {
                Toggle("Show Claude Button", isOn: $viewModel.showClaudeButton)

                Picker("Model", selection: $viewModel.terminalClaudeModelRaw) {
                    ForEach(claudeModels, id: \.id) { model in
                        Text(model.display).tag(model.id)
                    }
                }
                .disabled(!viewModel.showClaudeButton)

                TextField("Extra Flags", text: $viewModel.terminalClaudeFlags)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!viewModel.showClaudeButton)

                Text("Extra flags are appended to the claude command (e.g., --verbose)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("ccYOLO Button") {
                Toggle("Show ccYOLO Button", isOn: $viewModel.showCcyoloButton)

                Picker("Model", selection: $viewModel.terminalCcyoloModelRaw) {
                    ForEach(claudeModels, id: \.id) { model in
                        Text(model.display).tag(model.id)
                    }
                }
                .disabled(!viewModel.showCcyoloButton)

                Text("ccYOLO runs with --dangerously-skip-permissions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Codex Button") {
                Toggle("Show Codex Button", isOn: $viewModel.showCodexButton)

                Picker("Model", selection: $viewModel.terminalCodexModel) {
                    ForEach(codexModels, id: \.id) { model in
                        Text(model.display).tag(model.id)
                    }
                }
                .disabled(!viewModel.showCodexButton)
            }

            Section("Agent Teams (Swarm)") {
                Toggle("Enable Agent Teams", isOn: $viewModel.agentTeamsEnabled)

                Text("When enabled, projects can use multi-agent swarm mode. Each project can independently toggle swarm on/off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if viewModel.agentTeamsEnabled {
                    HStack {
                        Button(AgentTeamsService.agentTeamsGlobalEnabled ? "Remove Global Setting" : "Enable Globally") {
                            AgentTeamsService.setAgentTeamsGlobal(!AgentTeamsService.agentTeamsGlobalEnabled)
                            viewModel.objectWillChange.send()
                        }
                        .buttonStyle(.bordered)

                        Text(AgentTeamsService.agentTeamsGlobalEnabled
                            ? "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 is set in ~/.claude/settings.json"
                            : "Sets the environment variable globally for Claude Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Terminal")
    }
}

#Preview {
    TerminalSettingsView()
        .frame(width: 500, height: 600)
}
