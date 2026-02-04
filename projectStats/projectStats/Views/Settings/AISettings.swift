import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showKey = false
    @State private var showOpenAIKey = false
    @State private var showElevenLabsKey = false
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            // MARK: - AI Chat Provider
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
