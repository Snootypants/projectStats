import CloudKit
import Foundation

/// Resolution strategies for sync conflicts
enum ConflictResolution: String, CaseIterable, Codable {
    case useLocal = "use_local"
    case useRemote = "use_remote"
    case merge = "merge"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .useLocal: return "Keep Local"
        case .useRemote: return "Keep Remote"
        case .merge: return "Merge (Last Write Wins)"
        case .manual: return "Ask Each Time"
        }
    }

    var description: String {
        switch self {
        case .useLocal: return "Always prefer your local changes"
        case .useRemote: return "Always prefer changes from other devices"
        case .merge: return "Automatically merge based on timestamps"
        case .manual: return "Show a dialog to choose for each conflict"
        }
    }
}

/// Information about a detected conflict
struct ConflictInfo {
    let recordType: String
    let recordID: String
    let localModifiedAt: Date
    let serverModifiedAt: Date
    let localRecord: CKRecord?
    let serverRecord: CKRecord

    var newerIsLocal: Bool {
        localModifiedAt > serverModifiedAt
    }

    var timeDifference: TimeInterval {
        abs(localModifiedAt.timeIntervalSince(serverModifiedAt))
    }
}

/// Service for resolving sync conflicts
@MainActor
final class ConflictResolver: ObservableObject {
    static let shared = ConflictResolver()

    @Published var pendingConflicts: [ConflictInfo] = []
    @Published var defaultResolution: ConflictResolution = .merge

    private init() {
        loadSettings()
    }

    private func loadSettings() {
        if let raw = UserDefaults.standard.string(forKey: "sync.conflictResolution"),
           let resolution = ConflictResolution(rawValue: raw) {
            defaultResolution = resolution
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(defaultResolution.rawValue, forKey: "sync.conflictResolution")
    }

    // MARK: - Resolution

    /// Resolve a conflict based on the default strategy
    func resolve(_ conflict: ConflictInfo) -> CKRecord {
        switch defaultResolution {
        case .useLocal:
            return conflict.localRecord ?? conflict.serverRecord
        case .useRemote:
            return conflict.serverRecord
        case .merge:
            return attemptMerge(conflict)
        case .manual:
            // In manual mode, queue for user decision and return server for now
            pendingConflicts.append(conflict)
            return conflict.serverRecord
        }
    }

    /// Attempt to automatically merge based on last-write-wins
    func attemptMerge(_ conflict: ConflictInfo) -> CKRecord {
        if conflict.newerIsLocal, let localRecord = conflict.localRecord {
            return localRecord
        }
        return conflict.serverRecord
    }

    /// User manually resolves a conflict
    func manuallyResolve(_ conflict: ConflictInfo, keepLocal: Bool) -> CKRecord {
        pendingConflicts.removeAll { $0.recordID == conflict.recordID }

        if keepLocal, let localRecord = conflict.localRecord {
            return localRecord
        }
        return conflict.serverRecord
    }

    // MARK: - Type-Specific Merging

    /// Merge prompt records
    func mergePrompt(local: CKRecord?, server: CKRecord) -> CKRecord {
        guard let local else { return server }

        let localModified = local.modificationDate ?? Date.distantPast
        let serverModified = server.modificationDate ?? Date.distantPast

        if localModified > serverModified {
            return local
        }
        return server
    }

    /// Merge diff records
    func mergeDiff(local: CKRecord?, server: CKRecord) -> CKRecord {
        guard let local else { return server }

        let localModified = local.modificationDate ?? Date.distantPast
        let serverModified = server.modificationDate ?? Date.distantPast

        if localModified > serverModified {
            return local
        }
        return server
    }

    /// Merge session records - for sessions, we typically want to keep both
    func mergeSession(local: CKRecord?, server: CKRecord) -> CKRecord {
        // Sessions are usually unique events, prefer keeping the more complete one
        guard let local else { return server }

        let localTokens = (local.int(for: "inputTokens") ?? 0) + (local.int(for: "outputTokens") ?? 0)
        let serverTokens = (server.int(for: "inputTokens") ?? 0) + (server.int(for: "outputTokens") ?? 0)

        // Keep the one with more token data
        if localTokens > serverTokens {
            return local
        }
        return server
    }

    // MARK: - Conflict Detection

    /// Check if a server record conflicts with local data
    func detectConflict(serverRecord: CKRecord, localModifiedAt: Date?) -> Bool {
        guard let localModified = localModifiedAt,
              let serverModified = serverRecord.modificationDate else {
            return false
        }

        // Consider it a conflict if both modified within 1 second of each other
        // and the server record is older
        return serverModified < localModified && localModified.timeIntervalSince(serverModified) < 60
    }
}
