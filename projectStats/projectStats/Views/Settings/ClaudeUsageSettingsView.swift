import SwiftUI

struct ClaudeUsageSettingsView: View {
    // Use @AppStorage directly to avoid "Publishing changes from within view updates" warning
    // This occurs when @Published properties on an ObservableObject are modified during render
    @AppStorage(AppStorageKeys.ccusageShowCost) private var showCost = true
    @AppStorage(AppStorageKeys.ccusageShowChart) private var showChart = true
    @AppStorage(AppStorageKeys.ccusageShowInputTokens) private var showInputTokens = false
    @AppStorage(AppStorageKeys.ccusageShowOutputTokens) private var showOutputTokens = false
    @AppStorage(AppStorageKeys.ccusageShowCacheTokens) private var showCacheTokens = false
    @AppStorage(AppStorageKeys.ccusageShowModelBreakdown) private var showModelBreakdown = false
    @AppStorage(AppStorageKeys.ccusageDaysToShow) private var daysToShow = 7

    var body: some View {
        Form {
            Section("Display Options") {
                Toggle("Show Cost", isOn: $showCost)
                Toggle("Show 7-Day Chart", isOn: $showChart)
                Toggle("Show Input Tokens", isOn: $showInputTokens)
                Toggle("Show Output Tokens", isOn: $showOutputTokens)
                Toggle("Show Cache Tokens", isOn: $showCacheTokens)
                Toggle("Show Model Breakdown", isOn: $showModelBreakdown)
            }

            Section("History Range") {
                Picker("Days to show", selection: $daysToShow) {
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
