import SwiftUI

struct FocusModeView: View {
    @ObservedObject var terminalMonitor: TerminalOutputMonitor
    @ObservedObject var usageMonitor: ClaudePlanUsageService
    @ObservedObject var settings: SettingsViewModel = .shared
    var onDismiss: (() -> Void)? = nil

    @State private var pulseAnimation = false
    @State private var showScrollingPrompt = false

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

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
                        countdown: usageMonitor.fiveHourTimeRemaining,
                        isWeekly: false
                    )
                    focusBarView(
                        label: "Weekly",
                        percent: usageMonitor.sevenDayUtilization,
                        countdown: usageMonitor.sevenDayTimeRemaining,
                        isWeekly: true
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }

            // Scrolling prompt overlay
            if showScrollingPrompt {
                ScrollingPromptView()
                    .transition(.opacity)
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

            // Close button — bottom-right, always visible
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        dismissFocusMode()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .padding(24)
                    .help("Close Focus Mode (Esc)")
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { pulseAnimation = true }
        .onTapGesture { dismissFocusMode() }
        // Hidden buttons for keyboard shortcuts
        .background {
            Group {
                Button("") { dismissFocusMode() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("") { withAnimation { showScrollingPrompt.toggle() } }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        }
    }

    private func dismissFocusMode() {
        onDismiss?()
    }

    private func focusBarView(label: String, percent: Double, countdown: String, isWeekly: Bool) -> some View {
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
                        .fill(barColor(for: percent, isWeekly: isWeekly))
                        .frame(width: geo.size.width * min(percent, 1.0))
                    ShimmerOverlay()
                        .frame(width: geo.size.width * min(percent, 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .frame(height: 8)
        }
    }

    private func barColor(for value: Double, isWeekly: Bool) -> Color {
        if value >= 0.85 { return Color(hex: settings.warningBarColorHex) ?? .red }
        let hex = isWeekly ? settings.weeklyBarColorHex : settings.sessionBarColorHex
        return Color(hex: hex) ?? .blue
    }
}

#Preview {
    FocusModeView(terminalMonitor: TerminalOutputMonitor.shared, usageMonitor: ClaudePlanUsageService.shared)
}
