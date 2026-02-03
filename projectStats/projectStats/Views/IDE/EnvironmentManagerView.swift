import AppKit
import SwiftUI

struct EnvironmentManagerView: View {
    @StateObject private var viewModel: EnvironmentViewModel

    init(projectPath: URL) {
        _viewModel = StateObject(wrappedValue: EnvironmentViewModel(projectPath: projectPath))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            importBar
        }
        .onAppear {
            viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Environment Variables")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button("Apply to .env") {
                    viewModel.apply()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isApplying)
            }

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private var content: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField("Search variables", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)

                Spacer()

                Button("+ Add Variable") {
                    viewModel.addVariable()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if viewModel.variables.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredIndices, id: \.self) { index in
                            EnvironmentVariableRow(
                                variable: $viewModel.variables[index],
                                resolvedValue: viewModel.resolvedValue(for: viewModel.variables[index]),
                                keychainMissing: viewModel.isKeychainMissing(for: viewModel.variables[index]),
                                availableKeychainKeys: viewModel.availableKeychainKeys,
                                onSourceChange: { newSource in
                                    viewModel.updateSource(for: index, to: newSource)
                                }
                            )

                            Divider()
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No environment variables yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Import from an .env file or add a variable manually.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    private var importBar: some View {
        HStack(spacing: 8) {
            Text("Import from:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(".env.example") {
                viewModel.importEnvExample()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(".env.local") {
                viewModel.importEnvFile(named: ".env.local")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Other...") {
                openImportPanel()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func openImportPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        panel.message = "Choose a .env file to import"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.importEnvFile(at: url)
        }
    }
}

#Preview {
    EnvironmentManagerView(projectPath: URL(fileURLWithPath: "/tmp"))
}
