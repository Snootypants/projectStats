import SwiftUI

/// Settings view for AI provider configuration
struct AIProviderSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @StateObject private var providerRegistry = AIProviderRegistry.shared
    @State private var testingProvider: AIProviderType?
    @State private var testResult: (success: Bool, message: String)?
    @State private var showingAPIKeyField: AIProviderType?

    var body: some View {
        Form {
            // Default Model & Thinking Section
            Section("Default Settings") {
                Picker("Default Model", selection: $settingsViewModel.defaultModel) {
                    ForEach(AIModel.models(for: .claudeCode), id: \.self) { model in
                        HStack {
                            Text(model.displayName)
                            Spacer()
                            Text(model.costLabel)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model)
                    }
                }

                Picker("Thinking Level", selection: $settingsViewModel.defaultThinkingLevel) {
                    ForEach(ThinkingLevel.allCases, id: \.self) { level in
                        HStack {
                            Image(systemName: level.icon)
                            Text(level.displayName)
                            if level.budgetTokens > 0 {
                                Text("(\(level.budgetTokens) tokens)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(level)
                    }
                }

                Toggle("Show Model in Toolbar", isOn: $settingsViewModel.showModelInToolbar)
            }

            // Providers Section
            Section("AI Providers") {
                ForEach(AIProviderType.allCases, id: \.self) { providerType in
                    ProviderRow(
                        providerType: providerType,
                        providerRegistry: providerRegistry,
                        testingProvider: $testingProvider,
                        testResult: $testResult,
                        showingAPIKeyField: $showingAPIKeyField
                    )
                }
            }

            // API Keys Section
            Section("API Keys") {
                SecureField("Anthropic API Key", text: $settingsViewModel.aiApiKey)
                    .textFieldStyle(.roundedBorder)

                SecureField("OpenAI API Key", text: $settingsViewModel.openAIApiKey)
                    .textFieldStyle(.roundedBorder)

                SecureField("ElevenLabs API Key", text: $settingsViewModel.elevenLabsApiKey)
                    .textFieldStyle(.roundedBorder)
            }

            // Ollama Configuration Section
            Section("Ollama (Local)") {
                if let ollama = providerRegistry.provider(for: .ollama) {
                    HStack {
                        Text("Host")
                        Spacer()
                        TextField("localhost", text: Binding(
                            get: { ollama.ollamaHost ?? "localhost" },
                            set: { ollama.ollamaHost = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    }

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("11434", value: Binding(
                            get: { ollama.ollamaPort ?? 11434 },
                            set: { ollama.ollamaPort = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    }

                    Button("Test Connection") {
                        testConnection(for: .ollama)
                    }
                    .disabled(testingProvider == .ollama)
                }
            }

            // Test Result
            if let result = testResult {
                Section {
                    HStack {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.success ? .green : .red)
                        Text(result.message)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            providerRegistry.loadProviders(context: AppModelContainer.shared.mainContext)
        }
    }

    private func testConnection(for providerType: AIProviderType) {
        testingProvider = providerType
        testResult = nil

        Task {
            guard let provider = providerRegistry.provider(for: providerType) else {
                testResult = (false, "Provider not found")
                testingProvider = nil
                return
            }

            let result = await providerRegistry.testConnection(for: provider)
            testResult = result
            testingProvider = nil
        }
    }
}

/// Row for a single provider in the settings list
private struct ProviderRow: View {
    let providerType: AIProviderType
    @ObservedObject var providerRegistry: AIProviderRegistry
    @Binding var testingProvider: AIProviderType?
    @Binding var testResult: (success: Bool, message: String)?
    @Binding var showingAPIKeyField: AIProviderType?

    private var provider: AIProviderConfig? {
        providerRegistry.provider(for: providerType)
    }

    var body: some View {
        HStack {
            // Icon and name
            HStack(spacing: 10) {
                Image(systemName: providerType.icon)
                    .foregroundStyle(provider?.isEnabled == true ? .primary : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(providerType.displayName)
                        .font(.body)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Enable/disable toggle
            if let provider {
                Toggle("", isOn: Binding(
                    get: { provider.isEnabled },
                    set: { newValue in
                        provider.isEnabled = newValue
                        providerRegistry.updateProvider(provider, context: AppModelContainer.shared.mainContext)
                    }
                ))
                .labelsHidden()

                // Set as default button
                if provider.isEnabled && !provider.isDefault {
                    Button("Set Default") {
                        providerRegistry.setDefaultProvider(provider, context: AppModelContainer.shared.mainContext)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                // Default indicator
                if provider.isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }

                // Test button for API providers
                if providerType.requiresAPIKey {
                    Button {
                        testConnection()
                    } label: {
                        if testingProvider == providerType {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(testingProvider == providerType)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        guard let provider else { return "Not configured" }

        if !provider.isEnabled {
            return "Disabled"
        }

        if providerType.requiresAPIKey {
            if provider.apiKey?.isEmpty ?? true {
                return "API key required"
            }
            return "Configured"
        }

        if providerType.isCLITool {
            return "CLI tool"
        }

        return "Ready"
    }

    private func testConnection() {
        testingProvider = providerType
        testResult = nil

        Task {
            guard let provider else {
                testResult = (false, "Provider not found")
                testingProvider = nil
                return
            }

            let result = await providerRegistry.testConnection(for: provider)
            testResult = result
            testingProvider = nil
        }
    }
}

#Preview {
    AIProviderSettingsView(settingsViewModel: SettingsViewModel.shared)
        .frame(width: 500, height: 600)
}
