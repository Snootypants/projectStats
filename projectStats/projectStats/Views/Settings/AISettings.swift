import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showKey = false
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $viewModel.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                HStack {
                    if showKey {
                        TextField("API Key", text: $viewModel.aiApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $viewModel.aiApiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                TextField("Model", text: $viewModel.aiModel)
                    .textFieldStyle(.roundedBorder)

                if viewModel.aiProvider == .kimi {
                    TextField("Base URL", text: $viewModel.aiBaseURL)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Button("Test") {
                        testConnection()
                    }
                    .disabled(isTesting || viewModel.aiApiKey.isEmpty)

                    if isTesting {
                        ProgressView().controlSize(.small)
                    }

                    if let testResult {
                        Text(testResult)
                            .font(.caption)
                            .foregroundStyle(testResult.contains("Success") ? .green : .red)
                    }
                }
            } header: {
                Text("AI Features")
            } footer: {
                Text("BYOK: your API key stays on this Mac.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let response = await AIService.shared.send(prompt: "Say hello in one sentence.")
            testResult = response == nil ? "Error" : "Success"
            isTesting = false
        }
    }
}

#Preview {
    AISettingsView()
        .environmentObject(SettingsViewModel.shared)
}
