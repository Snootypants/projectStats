import Foundation
import AVFoundation

@MainActor
final class VoiceNoteRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var lastTranscription: String = ""

    private var audioRecorder: AVAudioRecorder?

    func startRecording() {
        let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("voicenote.m4a")
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
        } catch {
            isRecording = false
        }
    }

    func stopRecording() async -> String {
        audioRecorder?.stop()
        isRecording = false
        guard let url = audioRecorder?.url else { return "" }
        let transcript = await transcribeAudio(url)
        lastTranscription = transcript
        return transcript
    }

    private func transcribeAudio(_ url: URL) async -> String {
        // Placeholder for Whisper API or local transcription.
        return "(Transcription not configured)"
    }
}
