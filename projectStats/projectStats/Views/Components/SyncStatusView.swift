#if false // DISABLED: Requires paid Apple Developer account
import SwiftUI

/// Compact sync status view for toolbar
struct CompactSyncStatusView: View {
    @StateObject private var syncEngine = SyncEngine.shared
    @StateObject private var offlineQueue = OfflineQueueManager.shared

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
                .font(.system(size: 12))

            if offlineQueue.queuedOperations.count > 0 {
                Text("\(offlineQueue.queuedOperations.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(statusBackground)
        .cornerRadius(4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if syncEngine.isSyncing {
            ProgressView()
                .scaleEffect(0.5)
        } else if !offlineQueue.isOnline {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
        } else if syncEngine.syncError != nil {
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(.red)
        } else if offlineQueue.queuedOperations.count > 0 {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.blue)
        } else {
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.green)
        }
    }

    private var statusBackground: Color {
        if !offlineQueue.isOnline {
            return Color.orange.opacity(0.1)
        } else if syncEngine.syncError != nil {
            return Color.red.opacity(0.1)
        } else if syncEngine.isSyncing {
            return Color.blue.opacity(0.1)
        }
        return Color.primary.opacity(0.05)
    }
}

/// Full sync status view for settings
struct SyncStatusView: View {
    @StateObject private var syncEngine = SyncEngine.shared
    @StateObject private var offlineQueue = OfflineQueueManager.shared
    @StateObject private var cloudKit = CloudKitContainer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            HStack {
                statusBadge
                Spacer()
                syncNowButton
            }

            // Last sync info
            if let lastSync = syncEngine.lastSyncDate {
                HStack {
                    Text("Last synced:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastSync, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Pending operations
            if offlineQueue.queuedOperations.count > 0 {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.orange)
                    Text("\(offlineQueue.queuedOperations.count) pending operations")
                        .font(.caption)
                }
            }

            // Error display
            if let error = syncEngine.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(4)
    }

    private var statusColor: Color {
        if syncEngine.isSyncing {
            return .blue
        } else if !offlineQueue.isOnline {
            return .orange
        } else if syncEngine.syncError != nil {
            return .red
        }
        return .green
    }

    private var statusText: String {
        if syncEngine.isSyncing {
            return "Syncing..."
        } else if !offlineQueue.isOnline {
            return "Offline"
        } else if syncEngine.syncError != nil {
            return "Error"
        }
        return "Synced"
    }

    @ViewBuilder
    private var syncNowButton: some View {
        Button {
            Task {
                try? await syncEngine.performFullSync(context: AppModelContainer.shared.mainContext)
            }
        } label: {
            if syncEngine.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(syncEngine.isSyncing || !offlineQueue.isOnline)
    }
}

#Preview("Compact") {
    CompactSyncStatusView()
        .padding()
}

#Preview("Full") {
    SyncStatusView()
        .frame(width: 300)
        .padding()
}
#endif

import SwiftUI

/// Compact sync status view for toolbar (disabled)
struct CompactSyncStatusView: View {
    var body: some View {
        Label("Sync Off", systemImage: "icloud.slash")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(4)
    }
}

/// Full sync status view for settings (disabled)
struct SyncStatusView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cloud Sync")
                .font(.headline)
            Text("Coming Soon. CloudKit sync is disabled because it requires a paid Apple Developer account.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
}

#Preview("Compact") {
    CompactSyncStatusView()
        .padding()
}

#Preview("Full") {
    SyncStatusView()
        .frame(width: 300)
        .padding()
}
