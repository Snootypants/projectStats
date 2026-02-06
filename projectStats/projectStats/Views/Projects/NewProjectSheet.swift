import SwiftUI

struct NewProjectSheet: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var projectName = ""
    @State private var selectedType: ProjectType = .blank
    @State private var errorMessage: String?
    @State private var isCreating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Project")
                .font(.title2.bold())

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.headline)
                TextField("my-project", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }

            // Type picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Type")
                    .font(.headline)
                HStack(spacing: 8) {
                    ForEach(ProjectType.allCases) { type in
                        Button {
                            selectedType = type
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 16))
                                Text(type.rawValue)
                                    .font(.caption)
                            }
                            .frame(width: 64, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedType == type ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(selectedType == type ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Location
            VStack(alignment: .leading, spacing: 4) {
                Text("Location")
                    .font(.headline)
                Text(settingsVM.codeDirectory.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Change in Settings → General")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            // Actions
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
        .padding(24)
        .frame(width: 420, height: 360)
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
                // Reload projects then open new project
                await DashboardViewModel.shared.loadDataIfNeeded()
                tabManager.openProject(path: url.path)
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}
