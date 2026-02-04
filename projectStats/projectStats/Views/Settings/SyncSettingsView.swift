#if false // DISABLED: Requires paid Apple Developer account
import SwiftUI

/// Settings view for iCloud sync configuration
struct SyncSettingsView: View {
    @StateObject private var syncEngine = SyncEngine.shared
    @StateObject private var cloudKit = CloudKitContainer.shared
    @StateObject private var offlineQueue = OfflineQueueManager.shared
    @StateObject private var conflictResolver = ConflictResolver.shared

    // Sync settings
    @AppStorage("sync.enabled") private var syncEnabled = false
    @AppStorage("sync.prompts") private var syncPrompts = true
    @AppStorage("sync.diffs") private var syncDiffs = true
    @AppStorage("sync.aiSessions") private var syncAISessions = true
    @AppStorage("sync.timeEntries") private var syncTimeEntries = true
    @AppStorage("sync.achievements") private var syncAchievements = true
    @AppStorage("sync.automatic") private var syncAutomatic = true
    @AppStorage("sync.intervalMinutes") private var syncIntervalMinutes = 15

    var body: some View {
        Form {
            // Account Status Section
            Section("iCloud Account") {
                HStack {
                    Image(systemName: cloudKit.isSignedIn ? "checkmark.icloud.fill" : "xmark.icloud")
                        .foregroundStyle(cloudKit.isSignedIn ? .green : .red)
                    Text(cloudKit.isSignedIn ? "Signed in to iCloud" : "Not signed in")

                    Spacer()

                    Button("Check Status") {
                        Task {
                            await cloudKit.checkAccountStatus()
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Enable Sync Section
            Section("Sync Settings") {
                Toggle("Enable iCloud Sync", isOn: $syncEnabled)
                    .disabled(!cloudKit.isSignedIn)

                if syncEnabled {
                    // Data type toggles
                    Toggle("Sync Prompts", isOn: $syncPrompts)
                    Toggle("Sync Diffs", isOn: $syncDiffs)
                    Toggle("Sync AI Sessions", isOn: $syncAISessions)
                    Toggle("Sync Time Entries", isOn: $syncTimeEntries)
                    Toggle("Sync Achievements", isOn: $syncAchievements)
                }
            }

            // Auto-Sync Section
            if syncEnabled {
                Section("Automatic Sync") {
                    Toggle("Auto-sync in background", isOn: $syncAutomatic)

                    if syncAutomatic {
                        Picker("Sync Interval", selection: $syncIntervalMinutes) {
                            Text("5 minutes").tag(5)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("1 hour").tag(60)
                        }
                    }
                }

                // Conflict Resolution Section
                Section("Conflict Resolution") {
                    Picker("When conflicts occur", selection: $conflictResolver.defaultResolution) {
                        ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                            VStack(alignment: .leading) {
                                Text(resolution.displayName)
                                Text(resolution.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(resolution)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: conflictResolver.defaultResolution) { _, _ in
                        conflictResolver.saveSettings()
                    }
                }
            }

            // Status Section
            Section("Sync Status") {
                SyncStatusView()
            }

            // Actions Section
            Section("Actions") {
                Button("Sync Now") {
                    Task {
                        try? await syncEngine.performFullSync(context: AppModelContainer.shared.mainContext)
                    }
                }
                .disabled(syncEngine.isSyncing || !cloudKit.isSignedIn || !syncEnabled)

                if offlineQueue.queuedOperations.count > 0 {
                    Button("Clear Pending Operations (\(offlineQueue.queuedOperations.count))") {
                        offlineQueue.clearQueue()
                    }
                    .foregroundStyle(.red)
                }

                Button("Reset Sync State") {
                    UserDefaults.standard.removeObject(forKey: "cloudkit.serverChangeToken")
                    offlineQueue.clearQueue()
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .task {
            await cloudKit.checkAccountStatus()
        }
    }
}

#Preview {
    SyncSettingsView()
        .frame(width: 500, height: 700)
}
#endif

import SwiftUI

struct SyncSettingsView: View {
    @ObservedObject private var subscription = SubscriptionManager.shared

    var body: some View {
        Form {
            // Subscription check first
            if !subscription.hasCloudSyncAccess {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("Cloud Sync is a Pro Feature")
                            .font(.headline)

                        Text("Upgrade to sync your projects, prompts, and progress across all your devices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        NavigationLink("Unlock Pro") {
                            SubscriptionView()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                // Show sync settings when Pro is active
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Pro Active")
                                .font(.headline)
                        }

                        Text("iCloud Sync")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("CloudKit sync is currently disabled because it requires a paid Apple Developer account. Once the account is active, sync will be enabled automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    SyncSettingsView()
        .frame(width: 500, height: 400)
}
