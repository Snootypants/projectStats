import SwiftUI

struct FocusModeView: View {
    @ObservedObject var terminalMonitor: TerminalOutputMonitor
    @ObservedObject var usageMonitor: ClaudePlanUsageService
    @ObservedObject var settings: SettingsViewModel = .shared
    @Environment(\.dismiss) private var dismiss

    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Background
            Color.black

            // Main content
            VStack(spacing: 30) {
                Spacer()

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

                Spacer()

                // Dual lockout bars at bottom
                HStack(spacing: 16) {
                    focusBarView(
                        label: "Session",
                        percent: usageMonitor.fiveHourUtilization,
                        countdown: usageMonitor.fiveHourTimeRemaining
                    )
                    focusBarView(
                        label: "Weekly",
                        percent: usageMonitor.sevenDayUtilization,
                        countdown: usageMonitor.sevenDayTimeRemaining
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

            // Mode picker (bottom-left)
            VStack {
                Spacer()
                HStack {
                    HStack(spacing: 8) {
                        ForEach(["fire", "smoke", "cubes"], id: \.self) { mode in
                            Button(mode.capitalized) {
                                settings.focusModeEdgeFXRaw = mode
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundColor(settings.focusModeEdgeFXRaw == mode ? .white : .white.opacity(0.3))
                        }
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
                    Spacer()
                }
            }

            // Edge FX overlay (CAEmitterLayer particles)
            EdgeFXOverlayView(mode: settings.focusModeEdgeFX, intensity: 1.0)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear { pulseAnimation = true }
        .onTapGesture { dismiss() }
        .keyboardShortcut(.escape, modifiers: [])
    }

    private func focusBarView(label: String, percent: Double, countdown: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("\(label) (\(Int(percent * 100))%, resets \(countdown))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor(for: percent))
                        .frame(width: geo.size.width * min(percent, 1.0))
                }
            }
            .frame(height: 8)
        }
    }

    private func progressColor(for value: Double) -> Color {
        if value < 0.6 { return .green }
        if value < 0.85 { return .yellow }
        return .red
    }
}

#Preview {
    FocusModeView(terminalMonitor: TerminalOutputMonitor.shared, usageMonitor: ClaudePlanUsageService.shared)
}
