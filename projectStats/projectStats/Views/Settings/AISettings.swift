import SwiftUI

// MARK: - AI Model Options (for dropdown picker)

struct AIModelOption: Identifiable, Hashable {
    let id: String  // The actual model ID string sent to API
    let displayName: String

    static let anthropicModels: [AIModelOption] = [
        AIModelOption(id: "claude-opus-4-20250514", displayName: "Claude Opus 4"),
        AIModelOption(id: "claude-sonnet-4-20250514", displayName: "Claude Sonnet 4"),
        AIModelOption(id: "claude-haiku-4-20250514", displayName: "Claude Haiku 4"),
    ]

    static let openaiModels: [AIModelOption] = [
        AIModelOption(id: "gpt-4o", displayName: "GPT-4o"),
        AIModelOption(id: "gpt-4-turbo", displayName: "GPT-4 Turbo"),
        AIModelOption(id: "o1", displayName: "o1"),
        AIModelOption(id: "o3-mini", displayName: "o3-mini"),
    ]

    static let localModels: [AIModelOption] = [
        AIModelOption(id: "llama3.2", displayName: "Llama 3.2"),
        AIModelOption(id: "codellama", displayName: "Code Llama"),
        AIModelOption(id: "deepseek-coder", displayName: "DeepSeek Coder"),
    ]

    static let kimiModels: [AIModelOption] = [
        AIModelOption(id: "moonshot-v1-8k", displayName: "Moonshot v1 8K"),
        AIModelOption(id: "moonshot-v1-32k", displayName: "Moonshot v1 32K"),
    ]

    static func models(for provider: AIProvider) -> [AIModelOption] {
        switch provider {
        case .anthropic: return anthropicModels
        case .openai: return openaiModels
        case .local: return localModels
        case .kimi: return kimiModels
        }
    }
}

struct AISettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showKey = false
    @State private var showOpenAIKey = false
    @State private var showElevenLabsKey = false
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var showModelRefreshConfirmation = false

    private var availableModels: [AIModelOption] {
        AIModelOption.models(for: viewModel.aiProvider)
    }

    var body: some View {
        Form {
            // MARK: - AI Chat Provider
            Section {
                Picker("Provider", selection: $viewModel.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: viewModel.aiProvider) { _, newProvider in
                    // Auto-select first available model when provider changes
                    if let firstModel = AIModelOption.models(for: newProvider).first {
                        viewModel.aiModel = firstModel.id
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

                HStack {
                    Picker("Model", selection: $viewModel.aiModel) {
                        ForEach(availableModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    .labelsHidden()

                    Text("Model")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        showModelRefreshConfirmation = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh available models")
                }
                .alert("Models Updated", isPresented: $showModelRefreshConfirmation) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Model list is current as of the latest app update.")
                }

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
                Text("AI Chat")
            } footer: {
                Text("BYOK: your API key stays on this Mac.")
            }

            // MARK: - Voice & TTS
            Section {
                Toggle("Enable Text-to-Speech", isOn: $viewModel.ttsEnabled)

                Picker("TTS Provider", selection: Binding(
                    get: { TTSProvider(rawValue: viewModel.ttsProvider) ?? .system },
                    set: { viewModel.ttsProvider = $0.rawValue }
                )) {
                    ForEach(TTSProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .disabled(!viewModel.ttsEnabled)

                Toggle("Auto-transcribe voice notes", isOn: $viewModel.voiceAutoTranscribe)
            } header: {
                Text("Voice & TTS")
            } footer: {
                Text("Voice notes use OpenAI Whisper for transcription.")
            }

            // MARK: - OpenAI Settings
            Section {
                HStack {
                    if showOpenAIKey {
                        TextField("OpenAI API Key", text: $viewModel.openAIApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("OpenAI API Key", text: $viewModel.openAIApiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showOpenAIKey.toggle()
                    } label: {
                        Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                Link("Get API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            } header: {
                Text("OpenAI (Whisper + TTS)")
            } footer: {
                Text("Used for voice transcription and TTS when OpenAI provider is selected.")
            }

            // MARK: - ElevenLabs Settings
            Section {
                HStack {
                    if showElevenLabsKey {
                        TextField("ElevenLabs API Key", text: $viewModel.elevenLabsApiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("ElevenLabs API Key", text: $viewModel.elevenLabsApiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showElevenLabsKey.toggle()
                    } label: {
                        Image(systemName: showElevenLabsKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                TextField("Voice ID", text: $viewModel.elevenLabsVoiceId)
                    .textFieldStyle(.roundedBorder)

                Link("Get API Key & Voice ID", destination: URL(string: "https://elevenlabs.io/app/settings/api-keys")!)
                    .font(.caption)
            } header: {
                Text("ElevenLabs")
            } footer: {
                Text("Used for high-quality TTS when ElevenLabs provider is selected.")
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
