import Foundation

/// Centralized schema and migration version tracking.
/// All migration checks should reference these constants.
enum SchemaVersion {
    /// Current data migration version (used by DataMigrationService).
    /// Bump when projectstats.json parsing or CachedProject schema changes.
    static let dataVersion = 4

    /// Whether DBv2 migration has been completed.
    /// Tracks one-time migration from TimeEntry→ProjectSession, CachedCommit→DailyMetric.
    static var dbv2Completed: Bool {
        get { UserDefaults.standard.bool(forKey: "dbv2_migration_completed") }
        set { UserDefaults.standard.set(newValue, forKey: "dbv2_migration_completed") }
    }

    /// Stored data version (from UserDefaults).
    static var storedDataVersion: Int {
        get { UserDefaults.standard.integer(forKey: "dataVersion") }
        set { UserDefaults.standard.set(newValue, forKey: "dataVersion") }
    }

    /// Whether a data migration is needed.
    static var needsDataMigration: Bool {
        storedDataVersion < dataVersion
    }
}
