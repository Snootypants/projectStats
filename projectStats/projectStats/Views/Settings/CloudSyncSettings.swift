import SwiftUI

struct CloudSyncSettingsView: View {
    @StateObject private var syncService = CloudSyncService.shared
    @State private var showKey = false

    private let frequencyOptions = [15, 30, 60, 120, 360]

    var body: some View {
        Form {
            Section {
                TextField("Endpoint", text: $syncService.endpoint)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    if showKey {
                        TextField("API Key", text: $syncService.apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $syncService.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
            } header: {
                Text("Endpoint")
            }

            Section {
                Toggle("Chat messages", isOn: $syncService.includeChatMessages)
                Toggle("Project stats", isOn: $syncService.includeProjectStats)
                Toggle("Claude usage", isOn: $syncService.includeClaudeUsage)
                Toggle("Time tracking", isOn: $syncService.includeTimeTracking)
                Toggle("Achievements", isOn: $syncService.includeAchievements)
            } header: {
                Text("Sync Options")
            }

            Section {
                Picker("Sync frequency", selection: $syncService.syncFrequencyMinutes) {
                    ForEach(frequencyOptions, id: \.self) { value in
                        if value >= 60 {
                            Text("Every \(value / 60) hr").tag(value)
                        } else {
                            Text("Every \(value) min").tag(value)
                        }
                    }
                }
                .onChange(of: syncService.syncFrequencyMinutes) { _, _ in
                    syncService.startTimerIfNeeded()
                }

                HStack {
                    Text("Last sync")
                    Spacer()
                    if let last = syncService.lastSync {
                        Text(last.relativeString)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never")
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Sync Now") {
                    Task { await syncService.sync() }
                }

                if case .error(let message) = syncService.syncStatus {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    CloudSyncSettingsView()
}
