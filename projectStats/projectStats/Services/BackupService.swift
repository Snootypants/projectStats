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

        // Use ditto for zip (handles exclusions well)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c", "-k",
            "--sequesterRsrc",
            "--keepParent",
            "--exclude", ".git",
            "--exclude", "node_modules",
            "--exclude", ".build",
            "--exclude", "build",
            "--exclude", "DerivedData",
            "--exclude", ".DS_Store",
            "--exclude", "*.xcuserstate",
            "--exclude", ".swiftpm",
            "--exclude", "Pods",
            "--exclude", "*.xcworkspace",
            projectPath.path,
            outputURL.path
        ]

        let pipe = Pipe()
        process.standardError = pipe

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                Task.detached {
                    process.waitUntilExit()

                    await MainActor.run {
                        guard process.terminationStatus == 0 else {
                            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                            continuation.resume(throwing: BackupError.zipFailed(errorString))
                            return
                        }

                        do {
                            let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
                            let size = attrs[.size] as? Int64 ?? 0

                            continuation.resume(returning: BackupResult(url: outputURL, size: size, fileCount: 0))
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            } catch {
                continuation.resume(throwing: BackupError.zipFailed(error.localizedDescription))
            }
        }
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
