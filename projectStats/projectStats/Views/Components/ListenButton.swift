import SwiftUI

struct ListenButton: View {
    let text: String
    @StateObject private var tts = TTSService.shared

    var body: some View {
        Button {
            if tts.isSpeaking {
                tts.stop()
            } else {
                Task {
                    await tts.speak(text)
                }
            }
        } label: {
            HStack(spacing: 4) {
                if tts.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: tts.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                }
                Text(tts.isSpeaking ? "Stop" : "Listen")
            }
        }
        .buttonStyle(.bordered)
        .disabled(tts.isLoading)
        .help(tts.isSpeaking ? "Stop speaking" : "Read aloud")
    }
}

#Preview {
    ListenButton(text: "Hello, this is a test of the text to speech system.")
        .padding()
}
