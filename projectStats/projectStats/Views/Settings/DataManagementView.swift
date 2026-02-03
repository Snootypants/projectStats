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
