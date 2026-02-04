import AppKit
import AVFoundation
import Foundation

enum TTSProvider: String, CaseIterable {
    case openai = "openai"
    case elevenLabs = "elevenlabs"
    case system = "system"
}

@MainActor
final class TTSService: ObservableObject {
    static let shared = TTSService()

    @Published var isSpeaking = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = NSSpeechSynthesizer()

    private init() {}

    func speak(_ text: String) async {
        guard SettingsViewModel.shared.ttsEnabled else {
            errorMessage = "TTS is disabled. Enable it in Settings > AI."
            return
        }

        isLoading = true
        errorMessage = nil

        let provider = TTSProvider(rawValue: SettingsViewModel.shared.ttsProvider) ?? .system

        do {
            switch provider {
            case .openai:
                try await speakWithOpenAI(text)
            case .elevenLabs:
                try await speakWithElevenLabs(text)
            case .system:
                speakWithSystem(text)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func stop() {
        audioPlayer?.stop()
        synthesizer.stopSpeaking()
        isSpeaking = false
    }

    private func speakWithOpenAI(_ text: String) async throws {
        let apiKey = SettingsViewModel.shared.openAIApiKey
        guard !apiKey.isEmpty else {
            throw TTSError.missingAPIKey("OpenAI API key not configured")
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": "nova",
            "response_format": "mp3"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TTSError.apiError("OpenAI TTS error: \(errorText)")
        }

        try playAudioData(data)
    }

    private func speakWithElevenLabs(_ text: String) async throws {
        let apiKey = SettingsViewModel.shared.elevenLabsApiKey
        guard !apiKey.isEmpty else {
            throw TTSError.missingAPIKey("ElevenLabs API key not configured")
        }

        let voiceId = SettingsViewModel.shared.elevenLabsVoiceId.isEmpty
            ? "21m00Tcm4TlvDq8ikWAM"  // Default Rachel voice
            : SettingsViewModel.shared.elevenLabsVoiceId

        let urlString = "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.5
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TTSError.apiError("ElevenLabs error: \(errorText)")
        }

        try playAudioData(data)
    }

    private func speakWithSystem(_ text: String) {
        isSpeaking = true
        synthesizer.startSpeaking(text)
        // NSSpeechSynthesizer runs async, we approximate completion
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) * 0.05) { [weak self] in
            self?.isSpeaking = false
        }
    }

    private func playAudioData(_ data: Data) throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tts_\(Date().timeIntervalSince1970).mp3")
        try data.write(to: tempURL)

        audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
        audioPlayer?.prepareToPlay()
        isSpeaking = true
        audioPlayer?.play()

        // Monitor playback completion
        Task {
            while audioPlayer?.isPlaying == true {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await MainActor.run {
                self.isSpeaking = false
            }
        }
    }
}

enum TTSError: LocalizedError {
    case missingAPIKey(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .apiError(let message):
            return message
        }
    }
}
