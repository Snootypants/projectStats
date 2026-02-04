import Combine
import Foundation

#if false // DISABLED: Requires paid Apple Developer account
import CloudKit
import Foundation

/// Central CloudKit container management
@MainActor
final class CloudKitContainer: ObservableObject {
    static let shared = CloudKitContainer()

    // Container identifiers
    static let containerIdentifier = "iCloud.com.35bird.projectStats"
    static let customZoneName = "ProjectStatsZone"

    // CloudKit resources
    let container: CKContainer
    let privateDatabase: CKDatabase
    let sharedDatabase: CKDatabase

    // State
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isSignedIn = false
    @Published var lastError: Error?
    @Published var customZone: CKRecordZone?

    // Subscription IDs
    private let subscriptionIDPrefix = "projectstats-"

    private init() {
        container = CKContainer(identifier: Self.containerIdentifier)
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
    }

    // MARK: - Account Status

    /// Check the current iCloud account status
    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            accountStatus = status
            isSignedIn = status == .available

            if isSignedIn {
                print("[CloudKit] Signed in to iCloud")
            } else {
                print("[CloudKit] Not signed in: \(status)")
            }
        } catch {
            lastError = error
            isSignedIn = false
            print("[CloudKit] Account status error: \(error)")
        }
    }

    // MARK: - Custom Zone

    /// Set up the custom record zone
    func setupCustomZone() async throws {
        let zoneID = CKRecordZone.ID(zoneName: Self.customZoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        do {
            let savedZone = try await privateDatabase.save(zone)
            customZone = savedZone
            print("[CloudKit] Custom zone created/verified: \(savedZone.zoneID.zoneName)")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists, that's fine
            customZone = zone
            print("[CloudKit] Custom zone already exists")
        } catch {
            lastError = error
            throw error
        }
    }

    /// Get the custom zone ID
    var customZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.customZoneName, ownerName: CKCurrentUserDefaultName)
    }

    // MARK: - Subscriptions

    /// Set up CloudKit subscriptions for change notifications
    func setupSubscriptions() async throws {
        guard isSignedIn else {
            print("[CloudKit] Cannot setup subscriptions - not signed in")
            return
        }

        // Record types to subscribe to
        let recordTypes = [
            "Prompt",
            "Diff",
            "AISession",
            "TimeEntry",
            "Achievement"
        ]

        for recordType in recordTypes {
            try await setupSubscription(for: recordType)
        }

        print("[CloudKit] Subscriptions setup complete")
    }

    private func setupSubscription(for recordType: String) async throws {
        let subscriptionID = "\(subscriptionIDPrefix)\(recordType)"

        // Check if subscription already exists
        do {
            _ = try await privateDatabase.subscription(for: subscriptionID)
            print("[CloudKit] Subscription exists: \(subscriptionID)")
            return
        } catch let error as CKError where error.code == .unknownItem {
            // Subscription doesn't exist, create it
        }

        // Create new subscription
        let subscription = CKRecordZoneSubscription(
            zoneID: customZoneID,
            subscriptionID: subscriptionID
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await privateDatabase.save(subscription)
            print("[CloudKit] Created subscription: \(subscriptionID)")
        } catch {
            print("[CloudKit] Failed to create subscription \(subscriptionID): \(error)")
            throw error
        }
    }

    /// Remove all subscriptions
    func removeAllSubscriptions() async throws {
        let subscriptions = try await privateDatabase.allSubscriptions()

        for subscription in subscriptions where subscription.subscriptionID.hasPrefix(subscriptionIDPrefix) {
            try await privateDatabase.deleteSubscription(withID: subscription.subscriptionID)
            print("[CloudKit] Deleted subscription: \(subscription.subscriptionID)")
        }
    }

    // MARK: - User Info

    /// Get current user record ID
    func fetchUserRecordID() async throws -> CKRecord.ID {
        return try await container.userRecordID()
    }

    /// Discover the user's identity (if available)
    func discoverUserIdentity() async throws -> CKUserIdentity? {
        let userRecordID = try await fetchUserRecordID()
        return try await container.userIdentity(forUserRecordID: userRecordID)
    }

    // MARK: - Error Handling

    /// Handle CloudKit errors with appropriate actions
    func handleError(_ error: Error) -> CloudKitErrorAction {
        guard let ckError = error as? CKError else {
            return .retry(after: 5)
        }

        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return .queueForLater
        case .serviceUnavailable, .requestRateLimited:
            let retryAfter = ckError.retryAfterSeconds ?? 30
            return .retry(after: retryAfter)
        case .serverRecordChanged:
            return .resolveConflict
        case .notAuthenticated:
            return .requiresSignIn
        case .quotaExceeded:
            return .quotaExceeded
        case .zoneNotFound:
            return .recreateZone
        case .userDeletedZone:
            return .recreateZone
        case .changeTokenExpired:
            return .fullSync
        default:
            return .retry(after: 5)
        }
    }
}

// MARK: - Error Action Types

enum CloudKitErrorAction {
    case retry(after: TimeInterval)
    case queueForLater
    case resolveConflict
    case requiresSignIn
    case quotaExceeded
    case recreateZone
    case fullSync
}
#endif

// MARK: - Disabled CloudKit Stub

@MainActor
final class CloudKitContainer: ObservableObject {
    static let shared = CloudKitContainer()

    @Published var isSignedIn = false
    @Published var lastError: Error?

    private init() {}

    func checkAccountStatus() async {
        isSignedIn = false
        print("[CloudKit] Disabled - requires paid dev account")
    }
}

#if false // DISABLED: Requires paid Apple Developer account
// MARK: - CKError Extension

extension CKError {
    var retryAfterSeconds: TimeInterval? {
        return userInfo[CKErrorRetryAfterKey] as? TimeInterval
    }
}
#endif
