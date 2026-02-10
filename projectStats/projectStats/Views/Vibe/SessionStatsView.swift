import SwiftUI

struct SessionStatsView: View {
    @ObservedObject var viewModel: VibeChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Session state
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                Text(stateLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }

            Divider()

            // Timer
            VStack(alignment: .leading, spacing: 4) {
                Text("Elapsed")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(formattedTime)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            // Tool calls
            VStack(alignment: .leading, spacing: 4) {
                Text("Tool Calls")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("\(viewModel.toolCallCount)")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }

            // Tool breakdown
            if !viewModel.toolBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Breakdown")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    ForEach(viewModel.toolBreakdown.sorted(by: { $0.value > $1.value }), id: \.key) { tool, count in
                        HStack {
                            Text(tool)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(count)")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
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

            // Messages count
            Text("\(viewModel.messages.count) messages")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
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
