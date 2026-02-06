import Combine
import Foundation
import SwiftData

// MARK: - Disabled CloudKit Stub

@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var pendingChangesCount = 0

    private init() {}

    func performFullSync(context: ModelContext) async throws {
        throw SyncError.disabled
    }

    func pushLocalChanges(context: ModelContext) async throws {
        throw SyncError.disabled
    }

    func pullRemoteChanges(context: ModelContext) async throws {
        throw SyncError.disabled
    }

    func logSyncState() {}
}

enum SyncError: LocalizedError {
    case disabled
    case notSignedIn
    case subscriptionRequired
    case networkUnavailable
    case quotaExceeded
    case conflictDetected
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "CloudKit sync is currently disabled"
        case .notSignedIn:
            return "Not signed into iCloud"
        case .subscriptionRequired:
            return "Cloud sync requires a Pro subscription"
        case .networkUnavailable:
            return "Network unavailable"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .conflictDetected:
            return "Sync conflict detected"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
