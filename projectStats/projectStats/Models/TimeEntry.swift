import Foundation
import SwiftData

@Model
final class TimeEntry {
    var id: UUID
    var projectPath: String
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval
    var isManual: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        projectPath: String,
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        isManual: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.projectPath = projectPath
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.isManual = isManual
        self.notes = notes
    }
}
