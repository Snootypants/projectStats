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

    /// Creates a zip backup of the project
    /// Excludes: .git, node_modules, .build, build, DerivedData, .DS_Store
    func createBackup(for projectPath: URL) async throws -> BackupResult {
        let projectName = projectPath.lastPathComponent
        let timestamp = Self.timestampFormatter.string(from: Date())
        let zipName = "\(projectName)-\(timestamp).zip"

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let outputURL = downloadsURL.appendingPathComponent(zipName)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let r = Shell.runResult(
                    "ditto -c -k --sequesterRsrc --keepParent" +
                    " --exclude .git --exclude node_modules" +
                    " --exclude .build --exclude build" +
                    " --exclude DerivedData --exclude .DS_Store" +
                    " --exclude '*.xcuserstate' --exclude .swiftpm" +
                    " --exclude Pods --exclude '*.xcworkspace'" +
                    " '\(projectPath.path)' '\(outputURL.path)'"
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

    enum BackupError: LocalizedError {
        case zipFailed(String)

        var errorDescription: String? {
            switch self {
            case .zipFailed(let msg): return "Backup failed: \(msg)"
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()
}
