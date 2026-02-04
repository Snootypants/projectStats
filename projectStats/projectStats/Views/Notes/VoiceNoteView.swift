import SwiftUI

struct VoiceNoteView: View {
    let projectPath: URL?
    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var noteTitle = ""
    @State private var showSaveSuccess = false
    @State private var savedPath: URL?

    init(projectPath: URL? = nil) {
        self.projectPath = projectPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Notes")
                .font(.headline)

            HStack {
                Button {
                    if recorder.isRecording {
                        Task { _ = await recorder.stopRecording() }
                    } else {
                        recorder.startRecording()
                    }
                } label: {
                    HStack {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        Text(recorder.isRecording ? "Stop" : "Record")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(recorder.isRecording ? .red : .accentColor)
                .disabled(recorder.isTranscribing)

                if recorder.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Recording...")
                    }
                    .foregroundStyle(.secondary)
                }

                if recorder.isTranscribing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Transcribing...")
                    }
                    .foregroundStyle(.secondary)
                }
            }

            if let error = recorder.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if !recorder.lastTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(recorder.lastTranscription)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)

                    if projectPath != nil {
                        HStack {
                            TextField("Note title (optional)", text: $noteTitle)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)

                            Button("Save to .notes/") {
                                saveNote()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if showSaveSuccess, let path = savedPath {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Saved to \(path.lastPathComponent)")
                        .font(.caption)
                }
            }
        }
        .padding()
    }

    private func saveNote() {
        guard let projectPath = projectPath else { return }
        do {
            savedPath = try recorder.saveTranscription(to: projectPath, title: noteTitle.isEmpty ? nil : noteTitle)
            showSaveSuccess = true
            noteTitle = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSaveSuccess = false
            }
        } catch {
            recorder.errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    VoiceNoteView(projectPath: URL(fileURLWithPath: "/tmp/test-project"))
}
