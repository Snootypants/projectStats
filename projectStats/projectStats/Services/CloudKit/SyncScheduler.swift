import AppKit
import Combine
import Foundation

#if false // DISABLED: Requires paid Apple Developer account
import Foundation
import AppKit

/// Scheduler for background sync operations
@MainActor
final class SyncScheduler: ObservableObject {
    static let shared = SyncScheduler()

    @Published var isScheduled = false
    @Published var nextSyncDate: Date?

    private var syncTimer: Timer?
    private var debounceTask: Task<Void, Never>?

    private var syncIntervalMinutes: Int {
        UserDefaults.standard.integer(forKey: "sync.intervalMinutes").clamped(to: 5...120)
    }

    private var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "sync.enabled")
    }

    private var isAutoSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "sync.automatic")
    }

    private init() {
        setupNotificationObservers()
    }

    // MARK: - Scheduled Sync

    /// Start scheduled background sync
    func startScheduledSync() {
        guard isSyncEnabled && isAutoSyncEnabled else {
            print("[SyncScheduler] Sync not enabled")
            return
        }

        stopScheduledSync()

        let interval = TimeInterval(syncIntervalMinutes * 60)
        nextSyncDate = Date().addingTimeInterval(interval)

        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performScheduledSync()
            }
        }

        isScheduled = true
        print("[SyncScheduler] Started with interval: \(syncIntervalMinutes) minutes")
    }

    /// Stop scheduled sync
    func stopScheduledSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        nextSyncDate = nil
        isScheduled = false
        print("[SyncScheduler] Stopped")
    }

    /// Schedule a change-triggered sync with debounce
    func scheduleChangeSync() {
        debounceTask?.cancel()
        debounceTask = Task {
            // Wait 5 seconds before syncing to batch changes
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await performScheduledSync()
        }
    }

    private func performScheduledSync() async {
        guard isSyncEnabled else { return }
        guard CloudKitContainer.shared.isSignedIn else { return }
        guard OfflineQueueManager.shared.isOnline else {
            print("[SyncScheduler] Offline, skipping scheduled sync")
            return
        }

        print("[SyncScheduler] Performing scheduled sync")

        do {
            try await SyncEngine.shared.performFullSync(context: AppModelContainer.shared.mainContext)
            nextSyncDate = Date().addingTimeInterval(TimeInterval(syncIntervalMinutes * 60))
        } catch {
            print("[SyncScheduler] Sync failed: \(error)")
        }
    }

    // MARK: - App Lifecycle

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onAppBecameActive()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.onAppWillResignActive()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.onAppWillTerminate()
            }
        }
    }

    /// Called when app becomes active
    func onAppBecameActive() {
        // Check if we should sync on activation
        guard isSyncEnabled && isAutoSyncEnabled else { return }

        if let lastSync = SyncEngine.shared.lastSyncDate {
            let timeSinceLastSync = Date().timeIntervalSince(lastSync)
            let syncInterval = TimeInterval(syncIntervalMinutes * 60)

            if timeSinceLastSync > syncInterval {
                Task {
                    await performScheduledSync()
                }
            }
        }

        // Restart scheduled sync if needed
        if !isScheduled {
            startScheduledSync()
        }
    }

    /// Called when app will resign active
    func onAppWillResignActive() async {
        // Push any pending changes before going to background
        guard isSyncEnabled else { return }
        guard CloudKitContainer.shared.isSignedIn else { return }
        guard OfflineQueueManager.shared.isOnline else { return }

        do {
            try await SyncEngine.shared.pushLocalChanges(context: AppModelContainer.shared.mainContext)
            print("[SyncScheduler] Pushed changes before resigning active")
        } catch {
            print("[SyncScheduler] Failed to push changes: \(error)")
        }
    }

    /// Called when app will terminate
    func onAppWillTerminate() async {
        // Final sync before termination
        guard isSyncEnabled else { return }
        guard CloudKitContainer.shared.isSignedIn else { return }
        guard OfflineQueueManager.shared.isOnline else { return }

        do {
            try await SyncEngine.shared.pushLocalChanges(context: AppModelContainer.shared.mainContext)
            print("[SyncScheduler] Final sync completed before termination")
        } catch {
            print("[SyncScheduler] Final sync failed: \(error)")
        }
    }
}

// MARK: - Int Extension

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
#endif

// MARK: - Disabled CloudKit Stub

@MainActor
final class SyncScheduler: ObservableObject {
    static let shared = SyncScheduler()

    @Published var isScheduled = false
    @Published var nextSyncDate: Date?

    private init() {}

    func startScheduledSync() {
        print("[SyncScheduler] CloudKit disabled - requires paid dev account")
    }

    func stopScheduledSync() {
        isScheduled = false
        nextSyncDate = nil
    }

    func scheduleChangeSync() {
        print("[SyncScheduler] CloudKit disabled - requires paid dev account")
    }

    func onAppBecameActive() {}

    func onAppWillResignActive() async {}

    func onAppWillTerminate() async {}
}
