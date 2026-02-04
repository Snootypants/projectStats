import Foundation
import AVFoundation

@MainActor
final class VoiceNoteRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var lastTranscription: String = ""
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var lastRecordingURL: URL?

    func startRecording() {
        errorMessage = nil
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("voicenote_\(Date().timeIntervalSince1970).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            lastRecordingURL = audioURL
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            isRecording = false
        }
    }

    func stopRecording() async -> String {
        audioRecorder?.stop()
        isRecording = false
        guard let url = lastRecordingURL else { return "" }

        isTranscribing = true
        let transcript = await transcribeAudio(url)
        isTranscribing = false
        lastTranscription = transcript
        return transcript
    }

    private func transcribeAudio(_ url: URL) async -> String {
        let apiKey = SettingsViewModel.shared.openAIApiKey
        guard !apiKey.isEmpty else {
            errorMessage = "OpenAI API key not configured. Set it in Settings > AI."
            return ""
        }

        do {
            let audioData = try Data(contentsOf: url)
            let boundary = UUID().uuidString
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()
            // Model field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("whisper-1\r\n".data(using: .utf8)!)
            // Audio file field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                errorMessage = "Whisper API error: \(errorText)"
                return ""
            }

            struct WhisperResponse: Decodable {
                let text: String
            }
            let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
            return result.text
        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            return ""
        }
    }

    func saveTranscription(to projectPath: URL, title: String? = nil) throws -> URL {
        guard !lastTranscription.isEmpty else {
            throw VoiceNoteError.noTranscription
        }

        let notesDir = projectPath.appendingPathComponent(".notes")
        try FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = title?.isEmpty == false ? "\(timestamp)-\(title!).md" : "\(timestamp)-voice-note.md"
        let fileURL = notesDir.appendingPathComponent(filename)

        let content = """
        # Voice Note - \(timestamp)

        \(lastTranscription)
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

enum VoiceNoteError: LocalizedError {
    case noTranscription

    var errorDescription: String? {
        switch self {
        case .noTranscription:
            return "No transcription available to save"
        }
    }
}
