import Foundation
import SwiftData

@MainActor
final class TimeTrackingService: ObservableObject {
    static let shared = TimeTrackingService()

    @Published var currentProject: String?
    @Published var sessionStart: Date?
    @Published var todayTotal: TimeInterval = 0
    @Published var isPaused: Bool = false

    private var idleTimer: Timer?
    private var lastActivity: Date = Date()

    private init() {
        refreshTodayTotal()
    }

    func startTracking(project: String) {
        if currentProject != project {
            stopTracking()
        }

        currentProject = project
        sessionStart = Date()
        isPaused = false
        startIdleDetection()
    }

    func stopTracking() {
        guard let project = currentProject, let start = sessionStart else { return }
        let end = Date()
        let duration = end.timeIntervalSince(start)

        let entry = TimeEntry(
            projectPath: project,
            startTime: start,
            endTime: end,
            duration: duration,
            isManual: false
        )

        let context = AppModelContainer.shared.mainContext
        context.insert(entry)
        try? context.save()

        currentProject = nil
        sessionStart = nil
        isPaused = false
        idleTimer?.invalidate()
        idleTimer = nil
        refreshTodayTotal()
    }

    func pauseTracking() {
        guard !isPaused else { return }
        stopTracking()
        isPaused = true
    }

    func resumeTracking(project: String) {
        startTracking(project: project)
    }

    func recordActivity() {
        lastActivity = Date()
    }

    private func startIdleDetection() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            let idleTime = Date().timeIntervalSince(self.lastActivity)
            if idleTime > 300 {
                self.pauseTracking()
            }
        }
    }

    func refreshTodayTotal() {
        let context = AppModelContainer.shared.mainContext
        let startOfDay = Date().startOfDay
        let descriptor = FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.startTime >= startOfDay })
        let entries = (try? context.fetch(descriptor)) ?? []
        todayTotal = entries.reduce(0) { $0 + $1.duration }
    }
}
