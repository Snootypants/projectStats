import SwiftUI

struct NewProjectWizard: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectName = ""
    @State private var selectedType: ProjectType = .blank
    @State private var initGit = true
    @State private var initClaude = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Project")
                .font(.title2.bold())

            Form {
                TextField("Project Name", text: $projectName)
                    .textFieldStyle(.roundedBorder)

                Picker("Template", selection: $selectedType) {
                    ForEach(ProjectType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Toggle("Initialize Git", isOn: $initGit)
                Toggle("Create CLAUDE.md", isOn: $initClaude)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .font(.caption.bold())
                Text(settingsVM.codeDirectory.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Project") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
        }
        .padding()
        .frame(minWidth: 520)
    }

    private func createProject() {
        isCreating = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let context = AppModelContainer.shared.mainContext
                let url = try await ProjectCreationService.shared.createProject(
                    name: projectName,
                    type: selectedType,
                    baseDirectory: settingsVM.codeDirectory,
                    context: context
                )
                dismiss()
                await DashboardViewModel.shared.loadDataIfNeeded()
                tabManager.openProject(path: url.path)
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

#Preview {
    NewProjectWizard()
        .environmentObject(SettingsViewModel.shared)
        .environmentObject(TabManagerViewModel.shared)
}
