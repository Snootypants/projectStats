import SwiftUI

struct VoiceNoteView: View {
    @StateObject private var recorder = VoiceNoteRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Notes")
                .font(.headline)

            HStack {
                Button(recorder.isRecording ? "Stop" : "Record") {
                    if recorder.isRecording {
                        Task { _ = await recorder.stopRecording() }
                    } else {
                        recorder.startRecording()
                    }
                }
                .buttonStyle(.borderedProminent)

                if recorder.isRecording {
                    Text("Recording...")
                        .foregroundStyle(.secondary)
                }
            }

            if !recorder.lastTranscription.isEmpty {
                Text("Transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(recorder.lastTranscription)
                    .font(.body)
            }
        }
        .padding()
    }
}

#Preview {
    VoiceNoteView()
}
