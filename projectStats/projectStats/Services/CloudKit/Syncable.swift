import CloudKit
import Foundation

// MARK: - Syncable Protocol

/// Protocol for models that can be synced to CloudKit
protocol Syncable {
    /// Unique identifier for syncing
    var syncID: UUID { get }

    /// CloudKit record type name
    static var recordType: String { get }

    /// Convert to CKRecord
    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord

    /// Update from CKRecord
    mutating func update(from record: CKRecord)

    /// Last synced timestamp
    var lastSyncedAt: Date? { get set }

    /// Whether this record needs to be synced
    var needsSync: Bool { get }
}

// MARK: - Sync Metadata

/// Metadata for tracking sync state
struct SyncMetadata {
    var lastSyncedAt: Date?
    var serverChangeToken: Data?
    var localModifiedAt: Date
    var isDeleted: Bool

    init(localModifiedAt: Date = Date()) {
        self.localModifiedAt = localModifiedAt
        self.lastSyncedAt = nil
        self.serverChangeToken = nil
        self.isDeleted = false
    }

    var needsSync: Bool {
        guard let lastSynced = lastSyncedAt else { return true }
        return localModifiedAt > lastSynced
    }
}

// MARK: - CKRecord Extensions

extension CKRecord {
    /// Set a value if it's not nil
    func setIfPresent<T>(_ key: String, value: T?) {
        if let value = value as? CKRecordValue {
            self[key] = value
        }
    }

    // MARK: - Type-safe Getters

    /// Get string value
    func string(for key: String) -> String? {
        return self[key] as? String
    }

    /// Get int value
    func int(for key: String) -> Int? {
        return self[key] as? Int
    }

    /// Get int64 value
    func int64(for key: String) -> Int64? {
        return self[key] as? Int64
    }

    /// Get double value
    func double(for key: String) -> Double? {
        return self[key] as? Double
    }

    /// Get date value
    func date(for key: String) -> Date? {
        return self[key] as? Date
    }

    /// Get bool value
    func bool(for key: String) -> Bool {
        return (self[key] as? Int) == 1
    }

    /// Get UUID value
    func uuid(for key: String) -> UUID? {
        guard let string = self[key] as? String else { return nil }
        return UUID(uuidString: string)
    }

    /// Get data value
    func data(for key: String) -> Data? {
        return self[key] as? Data
    }

    /// Get string array value
    func stringArray(for key: String) -> [String]? {
        return self[key] as? [String]
    }

    // MARK: - Type-safe Setters

    /// Set string value
    func setString(_ key: String, _ value: String?) {
        self[key] = value as CKRecordValue?
    }

    /// Set int value
    func setInt(_ key: String, _ value: Int) {
        self[key] = value as CKRecordValue
    }

    /// Set int64 value
    func setInt64(_ key: String, _ value: Int64) {
        self[key] = value as CKRecordValue
    }

    /// Set double value
    func setDouble(_ key: String, _ value: Double) {
        self[key] = value as CKRecordValue
    }

    /// Set date value
    func setDate(_ key: String, _ value: Date?) {
        self[key] = value as CKRecordValue?
    }

    /// Set bool value
    func setBool(_ key: String, _ value: Bool) {
        self[key] = (value ? 1 : 0) as CKRecordValue
    }

    /// Set UUID value
    func setUUID(_ key: String, _ value: UUID) {
        self[key] = value.uuidString as CKRecordValue
    }

    /// Set data value
    func setData(_ key: String, _ value: Data?) {
        self[key] = value as CKRecordValue?
    }

    /// Set string array value
    func setStringArray(_ key: String, _ value: [String]?) {
        self[key] = value as CKRecordValue?
    }
}

// MARK: - Record ID Helpers

extension CKRecord.ID {
    /// Create a record ID from a UUID
    convenience init(syncID: UUID, recordType: String, zoneID: CKRecordZone.ID) {
        self.init(recordName: "\(recordType)-\(syncID.uuidString)", zoneID: zoneID)
    }

    /// Extract UUID from record ID
    var syncID: UUID? {
        let parts = recordName.components(separatedBy: "-")
        guard parts.count > 1 else { return nil }
        // UUID is everything after the first dash
        let uuidString = parts.dropFirst().joined(separator: "-")
        return UUID(uuidString: uuidString)
    }
}

// MARK: - Sync Change Types

/// Types of sync changes
enum SyncChangeType {
    case created
    case updated
    case deleted
}

/// Represents a pending sync operation
struct PendingSyncOperation: Identifiable, Codable {
    let id: UUID
    let recordType: String
    let recordID: String
    let changeType: String  // "created", "updated", "deleted"
    let timestamp: Date
    var retryCount: Int

    init(recordType: String, recordID: String, changeType: SyncChangeType) {
        self.id = UUID()
        self.recordType = recordType
        self.recordID = recordID
        self.timestamp = Date()
        self.retryCount = 0

        switch changeType {
        case .created: self.changeType = "created"
        case .updated: self.changeType = "updated"
        case .deleted: self.changeType = "deleted"
        }
    }

    var syncChangeType: SyncChangeType {
        switch changeType {
        case "created": return .created
        case "updated": return .updated
        case "deleted": return .deleted
        default: return .updated
        }
    }
}

// MARK: - Sync Conflict

/// Represents a sync conflict between local and remote versions
struct SyncConflict {
    let recordType: String
    let recordID: String
    let localModifiedAt: Date
    let serverModifiedAt: Date
    let localRecord: CKRecord?
    let serverRecord: CKRecord
}
