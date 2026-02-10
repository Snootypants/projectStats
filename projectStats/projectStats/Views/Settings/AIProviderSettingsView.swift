import SwiftUI

/// Settings view for AI provider configuration
struct AIProviderSettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @StateObject private var providerRegistry = AIProviderRegistry.shared
    @State private var testingProvider: AIProviderType?
    @State private var testResult: (success: Bool, message: String)?
    @State private var showingAPIKeyField: AIProviderType?
    @State private var keyTestState: KeyTestState = .idle

    enum KeyTestState: Equatable {
        case idle
        case testing(String) // which key
        case success(String)
        case failure(String)
    }

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
                HStack {
                    SecureField("Anthropic API Key", text: $settingsViewModel.aiApiKey)
                        .textFieldStyle(.roundedBorder)
                    keyTestButton(label: "Anthropic") {
                        await testAnthropicKey()
                    }
                }

                HStack {
                    SecureField("OpenAI API Key", text: $settingsViewModel.openAIApiKey)
                        .textFieldStyle(.roundedBorder)
                    keyTestButton(label: "OpenAI") {
                        await testOpenAIKey()
                    }
                }

                HStack {
                    SecureField("ElevenLabs API Key", text: $settingsViewModel.elevenLabsApiKey)
                        .textFieldStyle(.roundedBorder)
                    keyTestButton(label: "ElevenLabs") {
                        await testElevenLabsKey()
                    }
                }

                // Test result
                if case .success(let msg) = keyTestState {
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else if case .failure(let msg) = keyTestState {
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
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

    @ViewBuilder
    private func keyTestButton(label: String, action: @escaping () async -> Void) -> some View {
        Button {
            keyTestState = .testing(label)
            Task { await action() }
        } label: {
            if case .testing(let which) = keyTestState, which == label {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 40)
            } else {
                Text("Test")
                    .frame(width: 40)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(keyTestState != .idle && {
            if case .testing = keyTestState { return true }
            return false
        }())
    }

    private func testOpenAIKey() async {
        let key = settingsViewModel.openAIApiKey
        guard !key.isEmpty else {
            keyTestState = .failure("OpenAI key is empty")
            return
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                keyTestState = .success("OpenAI key is valid")
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                keyTestState = .failure("OpenAI: HTTP \(code)")
            }
        } catch {
            keyTestState = .failure("OpenAI: \(error.localizedDescription)")
        }
    }

    private func testAnthropicKey() async {
        let key = settingsViewModel.aiApiKey
        guard !key.isEmpty else {
            keyTestState = .failure("Anthropic key is empty")
            return
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Minimal request — will succeed or fail based on auth
        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                keyTestState = .success("Anthropic key is valid")
            } else if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                keyTestState = .failure("Anthropic: Invalid API key")
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                keyTestState = .failure("Anthropic: HTTP \(code)")
            }
        } catch {
            keyTestState = .failure("Anthropic: \(error.localizedDescription)")
        }
    }

    private func testElevenLabsKey() async {
        let key = settingsViewModel.elevenLabsApiKey
        guard !key.isEmpty else {
            keyTestState = .failure("ElevenLabs key is empty")
            return
        }

        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/user")!)
        request.setValue(key, forHTTPHeaderField: "xi-api-key")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                keyTestState = .success("ElevenLabs key is valid")
            } else if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                keyTestState = .failure("ElevenLabs: Invalid API key")
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                keyTestState = .failure("ElevenLabs: HTTP \(code)")
            }
        } catch {
            keyTestState = .failure("ElevenLabs: \(error.localizedDescription)")
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
