import SwiftUI

struct FocusModeView: View {
    @ObservedObject var terminalMonitor: TerminalOutputMonitor
    @ObservedObject var usageMonitor: ClaudePlanUsageService
    @Environment(\.dismiss) private var dismiss

    @State private var pulseAnimation = false

    private var progressColor: Color {
        let value = usageMonitor.fiveHourUtilization
        if value < 0.6 { return .green }
        if value < 0.85 { return .yellow }
        return .red
    }

    var body: some View {
        ZStack {
            // Background
            Color.black

            // Main content
            VStack(spacing: 30) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: pulseAnimation)

                    Text("Claude is working...")
                        .font(.title)
                        .foregroundColor(.white)
                }

                Text(terminalMonitor.activeProjectPath ?? "Analyzing...")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))

                VStack(spacing: 8) {
                    ProgressView(value: usageMonitor.fiveHourUtilization)
                        .tint(progressColor)
                        .frame(width: 300)

                    Text("Context: \(Int(usageMonitor.fiveHourUtilization * 100))%")
                        .foregroundColor(.white.opacity(0.6))
                }

                Divider()
                    .frame(width: 200)
                    .background(Color.white.opacity(0.2))

                HStack(spacing: 40) {
                    StatView(label: "Files", value: "--")
                    StatView(label: "Lines", value: "--")
                    StatView(label: "Time", value: "--")
                }
            }

            // Sparkle edge overlay
            SparkleEdgeEffect()
        }
        .ignoresSafeArea()
        .onAppear { pulseAnimation = true }
        .onTapGesture { dismiss() }
        .keyboardShortcut(.escape, modifiers: [])
    }
}

private struct StatView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

#Preview {
    FocusModeView(terminalMonitor: TerminalOutputMonitor.shared, usageMonitor: ClaudePlanUsageService.shared)
}
