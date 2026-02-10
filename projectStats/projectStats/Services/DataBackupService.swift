import Foundation
import os.log

/// Backs up SwiftData store files to a timestamped directory.
/// Call on app launch and before migrations to protect against data loss.
@MainActor
final class DataBackupService {
    static let shared = DataBackupService()
    private init() {}

    private let maxBackups = 5

    /// Backup the SwiftData persistent store files.
    /// Returns the backup directory URL on success, nil on failure.
    @discardableResult
    func backupStore() -> URL? {
        let fm = FileManager.default

        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            Log.data.error("[Backup] Cannot find Application Support directory")
            return nil
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.calebbelshe.projectStats"
        let storeDir = appSupport.appendingPathComponent(bundleID, isDirectory: true)

        // Find all default.store* files
        guard let items = try? fm.contentsOfDirectory(at: storeDir, includingPropertiesForKeys: nil) else {
            // Try root appSupport if bundleID subdir doesn't exist
            return backupFromDirectory(appSupport, fm: fm)
        }

        let storeFiles = items.filter { $0.lastPathComponent.hasPrefix("default.store") }
        guard !storeFiles.isEmpty else {
            Log.data.info("[Backup] No store files found to back up")
            return nil
        }

        return performBackup(storeFiles: storeFiles, fm: fm)
    }

    private func backupFromDirectory(_ dir: URL, fm: FileManager) -> URL? {
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            Log.data.error("[Backup] Cannot read directory: \(dir.path)")
            return nil
        }

        let storeFiles = items.filter { $0.lastPathComponent.hasPrefix("default.store") }
        guard !storeFiles.isEmpty else {
            Log.data.info("[Backup] No store files found in \(dir.path)")
            return nil
        }

        return performBackup(storeFiles: storeFiles, fm: fm)
    }

    private func performBackup(storeFiles: [URL], fm: FileManager) -> URL? {
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.calebbelshe.projectStats"
        let backupsRoot = appSupport.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let backupDir = backupsRoot.appendingPathComponent("backup-\(timestamp)", isDirectory: true)

        do {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

            for file in storeFiles {
                let dest = backupDir.appendingPathComponent(file.lastPathComponent)
                try fm.copyItem(at: file, to: dest)
            }

            Log.data.info("[Backup] Created backup with \(storeFiles.count) files at \(backupDir.lastPathComponent)")
            pruneOldBackups(in: backupsRoot, fm: fm)
            return backupDir
        } catch {
            Log.data.error("[Backup] Failed to create backup: \(error)")
            return nil
        }
    }

    private func pruneOldBackups(in backupsRoot: URL, fm: FileManager) {
        guard let items = try? fm.contentsOfDirectory(
            at: backupsRoot,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let backupDirs = items
            .filter { $0.lastPathComponent.hasPrefix("backup-") }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return dateA > dateB
            }

        if backupDirs.count > maxBackups {
            for old in backupDirs.dropFirst(maxBackups) {
                try? fm.removeItem(at: old)
                Log.data.info("[Backup] Pruned old backup: \(old.lastPathComponent)")
            }
        }
    }
}
