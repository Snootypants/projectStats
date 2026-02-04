import Foundation
import os.log

struct Log {
    private static let subsystem = "com.35bird.projectStats"

    static let general = Logger(subsystem: subsystem, category: "general")
    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let claude = Logger(subsystem: subsystem, category: "claude")
    static let git = Logger(subsystem: subsystem, category: "git")
    static let time = Logger(subsystem: subsystem, category: "timeTracking")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let subscription = Logger(subsystem: subsystem, category: "subscription")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
    static let messaging = Logger(subsystem: subsystem, category: "messaging")
}

// Usage examples:
// Log.sync.debug("Sync started")
// Log.claude.info("Session ended: \(tokens) tokens")
// Log.git.error("Failed to fetch: \(error)")
