import Combine
import Foundation
import SwiftData

#if false // DISABLED: Requires paid Apple Developer account
import CloudKit
import Foundation
import SwiftData

/// Core sync engine for CloudKit synchronization
@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var pendingChangesCount = 0

    private let cloudKit = CloudKitContainer.shared
    private var serverChangeToken: CKServerChangeToken?

    private init() {
        loadChangeToken()
    }

    // MARK: - Full Sync

    /// Perform a full sync (push local changes, then pull remote changes)
    func performFullSync(context: ModelContext) async throws {
        guard !isSyncing else { return }
        guard cloudKit.isSignedIn else {
            throw SyncError.notSignedIn
        }

        isSyncing = true
        syncError = nil

        defer {
            isSyncing = false
        }

        do {
            // Push local changes first
            try await pushLocalChanges(context: context)

            // Then pull remote changes
            try await pullRemoteChanges(context: context)

            lastSyncDate = Date()
            print("[SyncEngine] Full sync completed")
        } catch {
            syncError = error
            throw error
        }
    }

    // MARK: - Push Local Changes

    /// Push local changes to CloudKit
    func pushLocalChanges(context: ModelContext) async throws {
        let zoneID = cloudKit.customZoneID

        // Gather records to push
        var recordsToSave: [CKRecord] = []

        // Fetch prompts that need sync (simplified - in production, track needsSync flag)
        let prompts = try context.fetch(FetchDescriptor<SavedPrompt>())
        for prompt in prompts {
            recordsToSave.append(prompt.toCKRecord(zoneID: zoneID))
        }

        // Fetch diffs
        let diffs = try context.fetch(FetchDescriptor<SavedDiff>())
        for diff in diffs {
            recordsToSave.append(diff.toCKRecord(zoneID: zoneID))
        }

        // Fetch AI sessions
        let sessions = try context.fetch(FetchDescriptor<AISessionV2>())
        for session in sessions {
            recordsToSave.append(session.toCKRecord(zoneID: zoneID))
        }

        // Fetch time entries
        let timeEntries = try context.fetch(FetchDescriptor<TimeEntry>())
        for entry in timeEntries {
            recordsToSave.append(entry.toCKRecord(zoneID: zoneID))
        }

        guard !recordsToSave.isEmpty else {
            print("[SyncEngine] No records to push")
            return
        }

        // Batch save to CloudKit
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    print("[SyncEngine] Pushed \(recordsToSave.count) records")
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            cloudKit.privateDatabase.add(operation)
        }
    }

    // MARK: - Pull Remote Changes

    /// Pull remote changes from CloudKit
    func pullRemoteChanges(context: ModelContext) async throws {
        let zoneID = cloudKit.customZoneID

        let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        configuration.previousServerChangeToken = serverChangeToken

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: configuration]
        )

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        operation.recordWasChangedBlock = { _, result in
            switch result {
            case .success(let record):
                changedRecords.append(record)
            case .failure(let error):
                print("[SyncEngine] Record fetch error: \(error)")
            }
        }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            deletedRecordIDs.append(recordID)
        }

        operation.recordZoneChangeTokensUpdatedBlock = { _, token, _ in
            self.serverChangeToken = token
            self.saveChangeToken()
        }

        operation.recordZoneFetchResultBlock = { _, result in
            switch result {
            case .success(let (token, _, _)):
                self.serverChangeToken = token
                self.saveChangeToken()
            case .failure(let error):
                print("[SyncEngine] Zone fetch error: \(error)")
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    Task { @MainActor in
                        // Process changed records
                        for record in changedRecords {
                            self.processRemoteRecord(record, context: context)
                        }

                        // Process deletions
                        for recordID in deletedRecordIDs {
                            self.processRemoteDeletion(recordID, context: context)
                        }

                        try? context.save()
                        print("[SyncEngine] Pulled \(changedRecords.count) records, \(deletedRecordIDs.count) deletions")
                    }
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            cloudKit.privateDatabase.add(operation)
        }
    }

    // MARK: - Process Records

    private func processRemoteRecord(_ record: CKRecord, context: ModelContext) {
        switch record.recordType {
        case SavedPrompt.ckRecordType:
            processPromptRecord(record, context: context)
        case SavedDiff.ckRecordType:
            processDiffRecord(record, context: context)
        case AISessionV2.ckRecordType:
            processSessionRecord(record, context: context)
        case TimeEntry.ckRecordType:
            processTimeEntryRecord(record, context: context)
        default:
            print("[SyncEngine] Unknown record type: \(record.recordType)")
        }
    }

    private func processPromptRecord(_ record: CKRecord, context: ModelContext) {
        guard let id = record.uuid(for: "id") else { return }

        // Check if exists
        let descriptor = FetchDescriptor<SavedPrompt>(
            predicate: #Predicate<SavedPrompt> { $0.id == id }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.update(from: record)
        } else if let prompt = SavedPrompt.from(record: record) {
            context.insert(prompt)
        }
    }

    private func processDiffRecord(_ record: CKRecord, context: ModelContext) {
        // Similar implementation as processPromptRecord
    }

    private func processSessionRecord(_ record: CKRecord, context: ModelContext) {
        // Similar implementation as processPromptRecord
    }

    private func processTimeEntryRecord(_ record: CKRecord, context: ModelContext) {
        // Similar implementation as processPromptRecord
    }

    private func processRemoteDeletion(_ recordID: CKRecord.ID, context: ModelContext) {
        guard let syncID = recordID.syncID else { return }

        // Determine record type from ID and delete accordingly
        let recordName = recordID.recordName
        if recordName.hasPrefix("Prompt-") {
            let descriptor = FetchDescriptor<SavedPrompt>(
                predicate: #Predicate<SavedPrompt> { $0.id == syncID }
            )
            if let existing = try? context.fetch(descriptor).first {
                context.delete(existing)
            }
        }
        // Add similar handling for other types
    }

    // MARK: - Change Token Persistence

    private func loadChangeToken() {
        if let data = UserDefaults.standard.data(forKey: "cloudkit.serverChangeToken") {
            serverChangeToken = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: data
            )
        }
    }

    private func saveChangeToken() {
        if let token = serverChangeToken {
            let data = try? NSKeyedArchiver.archivedData(
                withRootObject: token,
                requiringSecureCoding: true
            )
            UserDefaults.standard.set(data, forKey: "cloudkit.serverChangeToken")
        }
    }
}

// MARK: - Sync Errors

enum SyncError: Error {
    case notSignedIn
    case networkUnavailable
    case quotaExceeded
    case conflictDetected
    case unknown(Error)
}
#endif

// MARK: - Disabled CloudKit Stub

@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var pendingChangesCount = 0

    private init() {
        print("[SyncEngine] Initialized (CloudKit disabled - requires paid dev account)")
    }

    func performFullSync(context: ModelContext) async throws {
        print("[SyncEngine] performFullSync() called")

        // Check subscription status first
        guard SubscriptionManager.shared.hasCloudSyncAccess else {
            print("[SyncEngine] ❌ Cloud sync requires Pro subscription")
            print("[SyncEngine] hasCloudSyncAccess = false")
            throw SyncError.subscriptionRequired
        }

        print("[SyncEngine] ✓ Subscription check passed")
        print("[SyncEngine] ⚠️ CloudKit disabled - requires paid Apple Developer account")
        print("[SyncEngine] To enable: Set #if true at top of SyncEngine.swift and configure CloudKit entitlements")
        throw SyncError.disabled
    }

    func pushLocalChanges(context: ModelContext) async throws {
        print("[SyncEngine] pushLocalChanges() called")

        // Check subscription status first
        guard SubscriptionManager.shared.hasCloudSyncAccess else {
            print("[SyncEngine] ❌ Cloud sync requires Pro subscription")
            throw SyncError.subscriptionRequired
        }

        print("[SyncEngine] ✓ Subscription check passed")
        print("[SyncEngine] ⚠️ CloudKit disabled - requires paid Apple Developer account")
        throw SyncError.disabled
    }

    func pullRemoteChanges(context: ModelContext) async throws {
        print("[SyncEngine] pullRemoteChanges() called")

        guard SubscriptionManager.shared.hasCloudSyncAccess else {
            print("[SyncEngine] ❌ Cloud sync requires Pro subscription")
            throw SyncError.subscriptionRequired
        }

        print("[SyncEngine] ⚠️ CloudKit disabled - requires paid Apple Developer account")
        throw SyncError.disabled
    }

    /// Debug helper to log sync state
    func logSyncState() {
        print("[SyncEngine] === Sync State ===")
        print("[SyncEngine] isSyncing: \(isSyncing)")
        print("[SyncEngine] lastSyncDate: \(lastSyncDate?.description ?? "never")")
        print("[SyncEngine] syncError: \(syncError?.localizedDescription ?? "none")")
        print("[SyncEngine] pendingChangesCount: \(pendingChangesCount)")
        print("[SyncEngine] hasCloudSyncAccess: \(SubscriptionManager.shared.hasCloudSyncAccess)")
        print("[SyncEngine] =====================")
    }
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
