import SwiftUI

struct PermissionCardView: View {
    let message: VibeChatMessage
    let onAllow: () -> Void
    let onDeny: () -> Void
    let onAllowAll: () -> Void

    var body: some View {
        if case .permissionRequest(let tool, let description, let command, let status) = message.content {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(statusColor(status))
                    Text("Permission Request")
                        .font(.caption.bold())
                        .foregroundStyle(statusColor(status))
                    Spacer()
                    statusBadge(status)
                }

                // Details
                HStack(spacing: 8) {
                    Text(tool)
                        .font(.caption.bold().monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let command, !command.isEmpty {
                    Text(command)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary.opacity(0.7))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                }

                // Action buttons (only when pending)
                if status == .pending {
                    HStack(spacing: 12) {
                        Button(action: onAllow) {
                            Label("Allow", systemImage: "checkmark.circle.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button(action: onDeny) {
                            Label("Deny", systemImage: "xmark.circle.fill")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Spacer()

                        Button(action: onAllowAll) {
                            Text("Allow All")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(statusColor(status).opacity(0.4), lineWidth: 1.5)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    private func statusColor(_ status: VibeChatMessage.PermissionStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .allowed, .autoApproved: return .green
        case .denied: return .red
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: VibeChatMessage.PermissionStatus) -> some View {
        switch status {
        case .pending:
            EmptyView()
        case .allowed:
            Label("Allowed", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .denied:
            Label("Denied", systemImage: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        case .autoApproved:
            Label("Auto-approved", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green.opacity(0.7))
        }
    }
}
