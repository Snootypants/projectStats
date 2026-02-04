import Foundation
import SwiftData

@Model
final class ClaudePlanUsageSnapshot {
    var id: UUID
    var capturedAt: Date

    // 5-hour window
    var fiveHourUtilization: Double
    var fiveHourResetsAt: Date?

    // 7-day window
    var sevenDayUtilization: Double
    var sevenDayResetsAt: Date?

    // Opus-only (optional)
    var opusUtilization: Double?
    var opusResetsAt: Date?

    // Sonnet-only (optional)
    var sonnetUtilization: Double?
    var sonnetResetsAt: Date?

    init(
        fiveHourUtilization: Double,
        fiveHourResetsAt: Date? = nil,
        sevenDayUtilization: Double,
        sevenDayResetsAt: Date? = nil,
        opusUtilization: Double? = nil,
        opusResetsAt: Date? = nil,
        sonnetUtilization: Double? = nil,
        sonnetResetsAt: Date? = nil
    ) {
        self.id = UUID()
        self.capturedAt = Date()
        self.fiveHourUtilization = fiveHourUtilization
        self.fiveHourResetsAt = fiveHourResetsAt
        self.sevenDayUtilization = sevenDayUtilization
        self.sevenDayResetsAt = sevenDayResetsAt
        self.opusUtilization = opusUtilization
        self.opusResetsAt = opusResetsAt
        self.sonnetUtilization = sonnetUtilization
        self.sonnetResetsAt = sonnetResetsAt
    }

    var fiveHourPercent: Int { Int(fiveHourUtilization * 100) }
    var sevenDayPercent: Int { Int(sevenDayUtilization * 100) }
}
