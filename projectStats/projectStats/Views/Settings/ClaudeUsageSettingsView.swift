import SwiftUI

struct ClaudeUsageSettingsView: View {
    @ObservedObject var viewModel = SettingsViewModel.shared

    var body: some View {
        Form {
            Section("Display Options") {
                Toggle("Show Cost", isOn: $viewModel.ccusageShowCost)
                Toggle("Show 7-Day Chart", isOn: $viewModel.ccusageShowChart)
                Toggle("Show Input Tokens", isOn: $viewModel.ccusageShowInputTokens)
                Toggle("Show Output Tokens", isOn: $viewModel.ccusageShowOutputTokens)
                Toggle("Show Cache Tokens", isOn: $viewModel.ccusageShowCacheTokens)
                Toggle("Show Model Breakdown", isOn: $viewModel.ccusageShowModelBreakdown)
            }

            Section("History Range") {
                Picker("Days to show", selection: $viewModel.ccusageDaysToShow) {
                    Text("7 Days").tag(7)
                    Text("14 Days").tag(14)
                    Text("30 Days").tag(30)
                }
                .pickerStyle(.segmented)
            }

            Section("Data Source") {
                Text("Data is fetched from ccusage CLI which reads Claude Code's local JSONL files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Refresh Now") {
                    Task {
                        await ClaudeUsageService.shared.refreshGlobal()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Claude Usage")
    }
}

#Preview {
    ClaudeUsageSettingsView()
}
