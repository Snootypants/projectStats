import Foundation
import os.log

/// Centralized logging for ProjectStats.
/// Uses Apple's unified logging system (Console.app compatible).
///
/// Usage:
///   Log.sync.info("Project synced")
///   Log.data.error("SwiftData fetch failed: \(error)")
///   Log.git.warning("Command timed out")
struct Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.calebbelshe.projectStats"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let claude = Logger(subsystem: subsystem, category: "claude")
    static let git = Logger(subsystem: subsystem, category: "git")
    static let time = Logger(subsystem: subsystem, category: "timeTracking")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let subscription = Logger(subsystem: subsystem, category: "subscription")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
    static let messaging = Logger(subsystem: subsystem, category: "messaging")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let terminal = Logger(subsystem: subsystem, category: "terminal")
    static let vibe = Logger(subsystem: subsystem, category: "vibe")
    static let xp = Logger(subsystem: subsystem, category: "xp")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let scanner = Logger(subsystem: subsystem, category: "scanner")
    static let shell = Logger(subsystem: subsystem, category: "shell")
}
