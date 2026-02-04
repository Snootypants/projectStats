import Combine
import Foundation

#if false // DISABLED: Requires paid Apple Developer account
import Foundation
import Network

/// Manages operations when offline and processes queue when back online
@MainActor
final class OfflineQueueManager: ObservableObject {
    static let shared = OfflineQueueManager()

    @Published var isOnline = true
    @Published var queuedOperations: [PendingSyncOperation] = []
    @Published var isProcessingQueue = false

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.35bird.projectStats.networkMonitor")
    private let queueKey = "sync.offlineQueue"

    private init() {
        loadQueue()
        startMonitoring()
    }

    deinit {
        pathMonitor.cancel()
    }

    // MARK: - Network Monitoring

    private func startMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied

                // Process queue when coming back online
                if !wasOnline && self?.isOnline == true {
                    await self?.processQueue()
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - Queue Management

    /// Queue an operation for later sync
    func queueOperation(_ operation: PendingSyncOperation) {
        queuedOperations.append(operation)
        saveQueue()
        print("[OfflineQueue] Queued \(operation.changeType) for \(operation.recordType)")
    }

    /// Queue a sync operation when offline
    func queueSyncOperation(recordType: String, recordID: String, changeType: SyncChangeType) {
        let operation = PendingSyncOperation(
            recordType: recordType,
            recordID: recordID,
            changeType: changeType
        )
        queueOperation(operation)
    }

    /// Process all queued operations
    func processQueue() async {
        guard isOnline else {
            print("[OfflineQueue] Still offline, cannot process queue")
            return
        }

        guard !isProcessingQueue else {
            print("[OfflineQueue] Already processing queue")
            return
        }

        guard !queuedOperations.isEmpty else {
            print("[OfflineQueue] Queue is empty")
            return
        }

        isProcessingQueue = true
        defer { isProcessingQueue = false }

        print("[OfflineQueue] Processing \(queuedOperations.count) queued operations")

        var failedOperations: [PendingSyncOperation] = []

        for var operation in queuedOperations {
            do {
                try await processOperation(operation)
            } catch {
                operation.retryCount += 1
                if operation.retryCount < 3 {
                    failedOperations.append(operation)
                } else {
                    print("[OfflineQueue] Operation failed after 3 retries: \(operation.recordID)")
                }
            }
        }

        queuedOperations = failedOperations
        saveQueue()

        print("[OfflineQueue] Queue processing complete. \(failedOperations.count) operations remaining")
    }

    private func processOperation(_ operation: PendingSyncOperation) async throws {
        // Trigger sync for the specific operation
        // This would call SyncEngine to sync the specific record
        print("[OfflineQueue] Processing \(operation.changeType) for \(operation.recordType): \(operation.recordID)")

        // For now, trigger a full sync
        // In production, this would be more targeted
        try await SyncEngine.shared.performFullSync(context: AppModelContainer.shared.mainContext)
    }

    /// Clear all queued operations
    func clearQueue() {
        queuedOperations.removeAll()
        saveQueue()
    }

    /// Remove a specific operation from the queue
    func removeOperation(_ operation: PendingSyncOperation) {
        queuedOperations.removeAll { $0.id == operation.id }
        saveQueue()
    }

    // MARK: - Persistence

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey) else { return }
        queuedOperations = (try? JSONDecoder().decode([PendingSyncOperation].self, from: data)) ?? []
    }

    private func saveQueue() {
        let data = try? JSONEncoder().encode(queuedOperations)
        UserDefaults.standard.set(data, forKey: queueKey)
    }
}
#endif

// MARK: - Disabled CloudKit Stub

@MainActor
final class OfflineQueueManager: ObservableObject {
    static let shared = OfflineQueueManager()

    @Published var isOnline = false
    @Published var queuedOperations: [PendingSyncOperation] = []
    @Published var isProcessingQueue = false

    private init() {}

    func queueOperation(_ operation: PendingSyncOperation) {
        queuedOperations.append(operation)
    }

    func queueSyncOperation(recordType: String, recordID: String, changeType: SyncChangeType) {
        let operation = PendingSyncOperation(recordType: recordType, recordID: recordID, changeType: changeType)
        queueOperation(operation)
    }

    func processQueue() async {
        print("[OfflineQueue] CloudKit disabled - requires paid dev account")
    }

    func clearQueue() {
        queuedOperations.removeAll()
    }

    func removeOperation(_ operation: PendingSyncOperation) {
        queuedOperations.removeAll { $0.id == operation.id }
    }
}
