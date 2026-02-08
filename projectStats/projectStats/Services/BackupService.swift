import Foundation
import AppKit

final class BackupService {
    static let shared = BackupService()
    private init() {}

    struct BackupResult {
        let url: URL
        let size: Int64
        let fileCount: Int
    }

    /// Returns the backup directory — user-configured or ~/Downloads
    var backupDirectory: URL {
        let custom = UserDefaults.standard.string(forKey: "backupDirectory") ?? ""
        if !custom.isEmpty {
            let url = URL(fileURLWithPath: custom)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    /// Creates a zip backup of the project using numbered naming (projectName-1.zip, projectName-2.zip, ...)
    /// Excludes: .git, node_modules, .build, build, DerivedData, .DS_Store
    func createBackup(for projectPath: URL) async throws -> BackupResult {
        let projectName = projectPath.lastPathComponent
        let outputDir = backupDirectory

        // Find next backup number
        let nextNumber = nextBackupNumber(projectName: projectName, in: outputDir)
        let zipName = "\(projectName)-\(nextNumber).zip"
        let outputURL = outputDir.appendingPathComponent(zipName)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        let parentDir = projectPath.deletingLastPathComponent().path
        let folderName = projectPath.lastPathComponent

        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let r = Shell.runResult(
                    "cd '\(parentDir)' && zip -r -q" +
                    " '\(outputURL.path)' '\(folderName)'" +
                    " -x '\(folderName)/.git/*'" +
                    " -x '\(folderName)/node_modules/*'" +
                    " -x '\(folderName)/.build/*'" +
                    " -x '\(folderName)/build/*'" +
                    " -x '\(folderName)/DerivedData/*'" +
                    " -x '*.DS_Store'" +
                    " -x '*.xcuserstate'" +
                    " -x '\(folderName)/.swiftpm/*'" +
                    " -x '\(folderName)/Pods/*'"
                )
                continuation.resume(returning: r)
            }
        }

        guard result.exitCode == 0 else {
            throw BackupError.zipFailed(result.error.isEmpty ? "Unknown error" : result.error)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let size = attrs[.size] as? Int64 ?? 0
        return BackupResult(url: outputURL, size: size, fileCount: 0)
    }

    /// Opens Finder with the backup file selected
    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    /// Finds the next sequential backup number for a project
    private func nextBackupNumber(projectName: String, in directory: URL) -> Int {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return 1
        }

        var maxNumber = 0
        let prefix = "\(projectName)-"
        for url in contents {
            let name = url.deletingPathExtension().lastPathComponent
            if name.hasPrefix(prefix), let numStr = name.dropFirst(prefix.count).components(separatedBy: CharacterSet.decimalDigits.inverted).first,
               let num = Int(numStr) {
                maxNumber = max(maxNumber, num)
            }
        }
        return maxNumber + 1
    }

    enum BackupError: LocalizedError {
        case zipFailed(String)

        var errorDescription: String? {
            switch self {
            case .zipFailed(let msg): return "Backup failed: \(msg)"
            }
        }
    }
}
