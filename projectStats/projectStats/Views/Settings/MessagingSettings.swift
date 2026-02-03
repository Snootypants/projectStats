import SwiftUI

struct MessagingSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showToken = false
    @State private var isTesting = false
    @State private var testResult: String?

    private let pollingOptions = [15, 30, 60, 120]

    var body: some View {
        Form {
            Section {
                Picker("Service", selection: $viewModel.messagingServiceType) {
                    ForEach(MessagingServiceType.allCases, id: \.self) { service in
                        Text(service.displayName).tag(service)
                    }
                }

                credentialsSection

                HStack {
                    Button("Test") { testMessaging() }
                        .disabled(isTesting)
                    if isTesting {
                        ProgressView().controlSize(.small)
                    }
                    Spacer()
                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Success") ? .green : .red)
                    }
                }
            } header: {
                Text("Messaging Service")
            }

            Section {
                Toggle("Claude session finished", isOn: $viewModel.notifyClaudeFinished)
                Toggle("Build completed", isOn: $viewModel.notifyBuildComplete)
                Toggle("Dev server started", isOn: $viewModel.notifyServerStart)
                Toggle("Context window > 80%", isOn: $viewModel.notifyContextHigh)
                Toggle("Plan usage > 75%", isOn: $viewModel.notifyPlanUsageHigh)
                Toggle("Git push completed", isOn: $viewModel.notifyGitPushCompleted)
                Toggle("Achievement unlocked", isOn: $viewModel.notifyAchievementUnlocked)
                Toggle("Enable messaging notifications", isOn: $viewModel.messagingNotificationsEnabled)
            } header: {
                Text("Notification Triggers")
            }

            Section {
                Toggle("Enable remote commands", isOn: $viewModel.remoteCommandsEnabled)
                    .onChange(of: viewModel.remoteCommandsEnabled) { _, _ in
                        MessagingService.shared.startPollingIfNeeded()
                    }

                Picker("Polling interval", selection: $viewModel.remoteCommandsInterval) {
                    ForEach(pollingOptions, id: \.self) { value in
                        Text("\(value) sec").tag(value)
                    }
                }
                .disabled(!viewModel.remoteCommandsEnabled)
                .onChange(of: viewModel.remoteCommandsInterval) { _, _ in
                    MessagingService.shared.startPollingIfNeeded()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("status  — Current project + server status")
                    Text("usage   — Claude plan limits")
                    Text("servers — List running dev servers")
                    Text("kill    — Stop a dev server")
                    Text("today   — Time tracked today")
                    Text("notify [on/off] — Toggle notifications")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("Remote Commands")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var credentialsSection: some View {
        switch viewModel.messagingServiceType {
        case .telegram:
            HStack {
                if showToken {
                    TextField("Bot Token", text: $viewModel.telegramBotToken)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("Bot Token", text: $viewModel.telegramBotToken)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    showToken.toggle()
                } label: {
                    Image(systemName: showToken ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }

            TextField("Chat ID", text: $viewModel.telegramChatId)
                .textFieldStyle(.roundedBorder)

        case .slack:
            TextField("Webhook URL", text: $viewModel.slackWebhookURL)
                .textFieldStyle(.roundedBorder)

        case .discord:
            TextField("Webhook URL", text: $viewModel.discordWebhookURL)
                .textFieldStyle(.roundedBorder)

        case .ntfy:
            TextField("Topic", text: $viewModel.messagingNtfyTopic)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func testMessaging() {
        isTesting = true
        testResult = nil

        Task {
            await MessagingService.shared.send(message: "ProjectStats test message")
            testResult = MessagingService.shared.lastError == nil ? "Success" : "Error"
            isTesting = false
        }
    }
}

#Preview {
    MessagingSettingsView()
        .environmentObject(SettingsViewModel.shared)
}
