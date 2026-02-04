import SwiftUI

struct DataManagementView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var dashboardViewModel: DashboardViewModel

    @State private var isScanning = false
    @State private var lastScanDate: Date?
    @State private var projectsFound: Int?
    @State private var promptsImported: Int?
    @State private var workLogsImported: Int?

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Working Folder:")
                    Text(settingsViewModel.codeDirectory.path)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Change") {
                        settingsViewModel.selectCodeDirectory()
                    }
                }

                Button {
                    Task { await scan() }
                } label: {
                    HStack {
                        if isScanning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Scan & Import All Projects")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning)

                Text("This will scan your working folder for projectstats.json files, prompts, and work logs, then import them into the database.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Last scan: \(lastScanDate?.relativeString ?? "Never")")
                    Text("Projects found: \(projectsFound.map(String.init) ?? "--")")
                    Text("Prompts imported: \(promptsImported.map(String.init) ?? "--")")
                    Text("Work logs imported: \(workLogsImported.map(String.init) ?? "--")")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // MARK: - DB v2 Status
            Section {
                let status = DBv2MigrationService.shared.getMigrationStatus(context: AppModelContainer.shared.mainContext)

                HStack {
                    Text("Migration Status")
                    Spacer()
                    Text(DBv2MigrationService.shared.hasMigrated ? "Completed" : "Pending")
                        .foregroundStyle(DBv2MigrationService.shared.hasMigrated ? .green : .orange)
                }

                HStack {
                    Text("Sessions")
                    Spacer()
                    Text("\(status.sessions)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Daily Metrics")
                    Spacer()
                    Text("\(status.dailyMetrics)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Work Items")
                    Spacer()
                    Text("\(status.workItems)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Weekly Goals")
                    Spacer()
                    Text("\(status.goals)")
                        .foregroundStyle(.secondary)
                }

                if !DBv2MigrationService.shared.hasMigrated {
                    Button("Run Migration") {
                        Task {
                            await DBv2MigrationService.shared.migrateIfNeeded(context: AppModelContainer.shared.mainContext)
                        }
                    }
                }
            } header: {
                Text("Database v2")
            } footer: {
                Text("Enhanced data models for sessions, metrics, work items, and goals.")
            }

            // MARK: - Danger Zone
            Section {
                Button(role: .destructive) {
                    Task {
                        await clearDatabase()
                    }
                } label: {
                    Text("Clear Database")
                }

                Text("Warning: This will remove all cached data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Danger Zone")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadCachedSummary()
        }
    }

    private func scan() async {
        isScanning = true
        defer { isScanning = false }

        let result = await dashboardViewModel.scanWorkingFolder(at: settingsViewModel.codeDirectory)
        lastScanDate = Date()
        projectsFound = result.projectsFound
        promptsImported = result.promptsImported
        workLogsImported = result.workLogsImported

        saveSummary()
    }

    private func clearDatabase() async {
        let context = AppModelContainer.shared.mainContext
        await DataMigrationService.shared.clearDatabase(modelContext: context)
        dashboardViewModel.projects = []
        dashboardViewModel.activities = [:]
        dashboardViewModel.aggregatedStats = .empty
    }

    private func loadCachedSummary() {
        let defaults = UserDefaults.standard
        if let timestamp = defaults.object(forKey: "data.lastScanDate") as? Date {
            lastScanDate = timestamp
        }
        if defaults.object(forKey: "data.lastScanProjects") != nil {
            projectsFound = defaults.integer(forKey: "data.lastScanProjects")
        }
        if defaults.object(forKey: "data.lastScanPrompts") != nil {
            promptsImported = defaults.integer(forKey: "data.lastScanPrompts")
        }
        if defaults.object(forKey: "data.lastScanWorkLogs") != nil {
            workLogsImported = defaults.integer(forKey: "data.lastScanWorkLogs")
        }
    }

    private func saveSummary() {
        let defaults = UserDefaults.standard
        defaults.set(lastScanDate, forKey: "data.lastScanDate")
        defaults.set(projectsFound ?? 0, forKey: "data.lastScanProjects")
        defaults.set(promptsImported ?? 0, forKey: "data.lastScanPrompts")
        defaults.set(workLogsImported ?? 0, forKey: "data.lastScanWorkLogs")
    }
}

#Preview {
    DataManagementView()
        .environmentObject(SettingsViewModel.shared)
        .environmentObject(DashboardViewModel.shared)
}
