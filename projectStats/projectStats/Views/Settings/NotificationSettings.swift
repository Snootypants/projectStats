import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    private let availableSounds = [
        "Ping",
        "Pop",
        "Glass",
        "Basso",
        "Hero"
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Show notification when Claude finishes", isOn: $viewModel.notifyClaudeFinished)
                Toggle("Play sound when Claude finishes", isOn: $viewModel.playSoundOnClaudeFinished)

                Picker("Sound", selection: $viewModel.notificationSound) {
                    ForEach(availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                .disabled(!viewModel.playSoundOnClaudeFinished)

                Toggle("Show notification when build completes", isOn: $viewModel.notifyBuildComplete)
                Toggle("Show notification when dev server starts", isOn: $viewModel.notifyServerStart)
                Toggle("Show notification when context > 80%", isOn: $viewModel.notifyContextHigh)
                Toggle("Show notification when plan usage > 75%", isOn: $viewModel.notifyPlanUsageHigh)
                Toggle("Show notification when git push completes", isOn: $viewModel.notifyGitPushCompleted)
                Toggle("Show notification when achievement unlocks", isOn: $viewModel.notifyAchievementUnlocked)
            }

            Section {
                Toggle("Push notifications to phone (requires setup)", isOn: $viewModel.pushNotificationsEnabled)

                HStack {
                    Text("Service")
                    Spacer()
                    Text("ntfy.sh")
                        .foregroundStyle(.secondary)
                }

                TextField("Topic", text: $viewModel.ntfyTopic)

                Button("Test Notification") {
                    viewModel.testNotification()
                }
                .disabled(!viewModel.pushNotificationsEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    NotificationSettingsView()
        .environmentObject(SettingsViewModel.shared)
}
