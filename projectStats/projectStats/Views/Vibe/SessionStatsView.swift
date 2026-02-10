import SwiftUI

struct SessionStatsView: View {
    @ObservedObject var viewModel: VibeChatViewModel
    var onToggleCode: (() -> Void)?
    @State private var cachedEstimate: SessionEstimator.Estimate?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Session state + Code button
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                Text(stateLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                Spacer()
                if let onToggleCode {
                    Button(action: onToggleCode) {
                        HStack(spacing: 4) {
                            Text("</>")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            Text("Code")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 0)
                    }
                    .buttonStyle(.plain)
                    .help("Switch back to Code mode")
                }
            }

            if viewModel.sessionState != .idle {
                Divider()

                // Timer
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formattedTime)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            } else if let estimate = cachedEstimate {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Typical Session")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 8) {
                        Label(estimate.formattedMedianDuration, systemImage: "clock")
                        Label(estimate.formattedMedianCost, systemImage: "dollarsign.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text("Based on \(estimate.sampleSize) sessions")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }

            if viewModel.sessionState != .idle {

                // Tool calls
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tool Calls")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(viewModel.toolCallCount)")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
            }

            // Live tokens
            if viewModel.liveInputTokens > 0 || viewModel.liveOutputTokens > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tokens")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack {
                        Text("In:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTokenCount(viewModel.liveInputTokens))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    HStack {
                        Text("Out:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTokenCount(viewModel.liveOutputTokens))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    if viewModel.liveCacheReadTokens > 0 {
                        HStack {
                            Text("Cache:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatTokenCount(viewModel.liveCacheReadTokens))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }

            // Tool breakdown with bars
            if !viewModel.toolBreakdown.isEmpty {
                let sorted = viewModel.toolBreakdown.sorted(by: { $0.value > $1.value })
                let maxCount = sorted.first?.value ?? 1
                VStack(alignment: .leading, spacing: 4) {
                    Text("Breakdown")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    ForEach(sorted, id: \.key) { tool, count in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(tool)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                            }
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(toolBarColor(tool))
                                    .frame(width: max(4, geo.size.width * CGFloat(count) / CGFloat(maxCount)))
                            }
                            .frame(height: 4)
                        }
                    }
                }
            }

            // Permission stats (sans flavor only)
            if viewModel.selectedPermissionMode == .sansFlavor && viewModel.approvalsTotal > 0 {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Approvals")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("\(viewModel.approvalsGranted) / \(viewModel.approvalsTotal)")
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
            }

            // Memory indexing status
            if viewModel.sessionState == .done {
                Divider()
                memoryStatus
            }

            Spacer()

            // Export button
            if !viewModel.rawLines.isEmpty {
                Button(action: exportJSON) {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Messages count
            HStack {
                Text("\(viewModel.messages.count) messages")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !viewModel.rawLines.isEmpty {
                    Text("\(viewModel.rawLines.count) events")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            cachedEstimate = SessionEstimator.shared.estimate(projectPath: viewModel.projectPath)
        }
        .onChange(of: viewModel.sessionState) { _, newState in
            if newState == .idle || newState == .done {
                cachedEstimate = SessionEstimator.shared.estimate(projectPath: viewModel.projectPath)
            }
        }
    }

    private func exportJSON() {
        let panel = NSSavePanel()
        panel.title = "Export Session JSON"
        panel.nameFieldStringValue = "vibe-session.jsonl"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let dest = panel.url else { return }

        let content = viewModel.rawLines.joined(separator: "\n")
        try? content.write(to: dest, atomically: true, encoding: .utf8)
    }

    @ObservedObject private var memoryPipeline = MemoryPipeline.shared

    @ViewBuilder
    private var memoryStatus: some View {
        switch memoryPipeline.indexingState {
        case .idle:
            EmptyView()
        case .indexing:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text("Indexing session...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .done:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                Text("Session indexed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption2)
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func toolBarColor(_ name: String) -> Color {
        switch name {
        case "Bash": return .orange
        case "Read": return .blue
        case "Write": return .green
        case "Edit": return .purple
        case "Grep": return .cyan
        case "Glob": return .yellow
        case "Task": return .pink
        default: return .gray
        }
    }

    private var stateColor: Color {
        switch viewModel.sessionState {
        case .idle: return .gray
        case .running: return .blue
        case .thinking: return .purple
        case .waitingForApproval: return .orange
        case .done: return .green
        case .error: return .red
        }
    }

    private var stateLabel: String {
        switch viewModel.sessionState {
        case .idle: return "Idle"
        case .running: return "Working..."
        case .thinking: return "Thinking..."
        case .waitingForApproval: return "Waiting for approval"
        case .done: return "Done"
        case .error(let msg): return "Error: \(msg.prefix(30))"
        }
    }

    private var formattedTime: String {
        let total = Int(viewModel.elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
