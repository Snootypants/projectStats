import Foundation
import SwiftData
import AppKit
import IOKit

@MainActor
final class TimeTrackingService: ObservableObject {
    static let shared = TimeTrackingService()

    // Current state
    @Published var currentProject: String?
    @Published var humanSessionStart: Date?
    @Published var aiSessionStart: Date?
    @Published var currentAIType: String?  // "claude_code", "codex"

    // Computed totals (refresh periodically)
    @Published var todayHumanTotal: TimeInterval = 0
    @Published var todayAITotal: TimeInterval = 0
    @Published var projectHumanTotal: TimeInterval = 0
    @Published var projectAITotal: TimeInterval = 0

    @Published var isPaused: Bool = false

    private var idleTimer: Timer?
    private var lastActivity: Date = Date()
    private let idleThreshold: TimeInterval = 300  // 5 minutes

    private init() {
        setupActivityMonitoring()
        refreshTotals()
    }

    // MARK: - Human Time Tracking

    func startHumanTracking(project: String) {
        // If switching projects, save current session
        if currentProject != project {
            stopHumanTracking()
        }

        currentProject = project
        humanSessionStart = Date()
        isPaused = false
        startIdleDetection()
        refreshTotals()
    }

    func stopHumanTracking() {
        guard let project = currentProject, let start = humanSessionStart else { return }

        let entry = TimeEntry(
            projectPath: project,
            startTime: start,
            endTime: Date(),
            duration: Date().timeIntervalSince(start),
            sessionType: "human"
        )

        saveEntry(entry)
        humanSessionStart = nil
        refreshTotals()
    }

    // Legacy compatibility methods
    func startTracking(project: String) {
        startHumanTracking(project: project)
    }

    func stopTracking() {
        stopHumanTracking()
        stopAITracking()
        currentProject = nil
        isPaused = false
        idleTimer?.invalidate()
        idleTimer = nil
    }

    // MARK: - AI Time Tracking

    func startAITracking(project: String, aiType: String, model: String? = nil) {
        // Don't start if already tracking AI for this project
        guard aiSessionStart == nil || currentProject != project else { return }

        currentProject = project
        aiSessionStart = Date()
        currentAIType = aiType

        Log.time.info("[TimeTracking] AI session started: \(aiType) for \(project)")
    }

    func stopAITracking(tokensUsed: Int? = nil) {
        guard let project = currentProject, let start = aiSessionStart, let aiType = currentAIType else { return }

        let entry = TimeEntry(
            projectPath: project,
            startTime: start,
            endTime: Date(),
            duration: Date().timeIntervalSince(start),
            sessionType: aiType,
            tokensUsed: tokensUsed
        )

        saveEntry(entry)
        aiSessionStart = nil
        currentAIType = nil
        refreshTotals()

        Log.time.info("[TimeTracking] AI session ended: \(aiType) duration: \(entry.duration)s")
    }

    // MARK: - Idle Detection

    func recordActivity() {
        lastActivity = Date()

        // Resume if was paused
        if isPaused, currentProject != nil {
            isPaused = false
            humanSessionStart = Date()
            Log.time.info("[TimeTracking] Resumed from idle")
        }
    }

    private func startIdleDetection() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdle()
            }
        }
    }

    private func checkIdle() {
        let idleTime = Date().timeIntervalSince(lastActivity)

        // Also check system-wide idle time
        let systemIdle = systemIdleTime()
        let effectiveIdle = max(idleTime, systemIdle)

        if effectiveIdle > idleThreshold && !isPaused {
            pauseTracking()
        }
    }

    private func systemIdleTime() -> TimeInterval {
        // Get system-wide idle time from IOKit
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator) == KERN_SUCCESS else {
            return 0
        }

        let entry = IOIteratorNext(iterator)
        defer {
            IOObjectRelease(entry)
            IOObjectRelease(iterator)
        }

        guard entry != 0 else { return 0 }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = properties?.takeRetainedValue() as? [String: Any],
              let idleTime = dict["HIDIdleTime"] as? Int64 else {
            return 0
        }

        return TimeInterval(idleTime) / 1_000_000_000  // Convert from nanoseconds
    }

    func pauseTracking() {
        guard !isPaused else { return }

        // Save current human session
        if let project = currentProject, let start = humanSessionStart {
            let entry = TimeEntry(
                projectPath: project,
                startTime: start,
                endTime: Date(),
                duration: Date().timeIntervalSince(start),
                sessionType: "human"
            )
            saveEntry(entry)
            humanSessionStart = nil
        }

        isPaused = true
        Log.time.info("[TimeTracking] Paused due to idle")
    }

    func resumeTracking(project: String) {
        startHumanTracking(project: project)
    }

    // MARK: - Activity Monitoring

    private func setupActivityMonitoring() {
        // Monitor global mouse/keyboard events
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]) { [weak self] _ in
            Task { @MainActor in
                self?.recordActivity()
            }
        }

        // Also monitor local events (when app is active)
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]) { [weak self] event in
            Task { @MainActor in
                self?.recordActivity()
            }
            return event
        }
    }

    // MARK: - Helpers

    private func saveEntry(_ entry: TimeEntry) {
        let context = AppModelContainer.shared.mainContext
        context.insert(entry)
        try? context.save()
    }

    func refreshTotals() {
        let context = AppModelContainer.shared.mainContext
        let startOfDay = Date().startOfDay

        // Today's totals
        let todayDescriptor = FetchDescriptor<TimeEntry>(predicate: #Predicate { $0.startTime >= startOfDay })
        let todayEntries = (try? context.fetch(todayDescriptor)) ?? []

        todayHumanTotal = todayEntries.filter { $0.sessionType == "human" }.reduce(0) { $0 + $1.duration }
        todayAITotal = todayEntries.filter { $0.sessionType != "human" }.reduce(0) { $0 + $1.duration }

        // Current project totals (if tracking)
        if let project = currentProject {
            let projectDescriptor = FetchDescriptor<TimeEntry>(predicate: #Predicate {
                $0.projectPath == project && $0.startTime >= startOfDay
            })
            let projectEntries = (try? context.fetch(projectDescriptor)) ?? []

            projectHumanTotal = projectEntries.filter { $0.sessionType == "human" }.reduce(0) { $0 + $1.duration }
            projectAITotal = projectEntries.filter { $0.sessionType != "human" }.reduce(0) { $0 + $1.duration }
        }
    }

    // MARK: - Formatted Output

    var todayHumanFormatted: String {
        formatDuration(todayHumanTotal + (humanSessionStart.map { Date().timeIntervalSince($0) } ?? 0))
    }

    var todayAIFormatted: String {
        formatDuration(todayAITotal + (aiSessionStart.map { Date().timeIntervalSince($0) } ?? 0))
    }

    var projectTimeFormatted: String {
        let human = projectHumanTotal + (humanSessionStart.map { Date().timeIntervalSince($0) } ?? 0)
        return formatDuration(human)
    }

    // Legacy compatibility
    var todayTotal: TimeInterval {
        todayHumanTotal + todayAITotal
    }

    var sessionStart: Date? {
        humanSessionStart
    }

    func refreshTodayTotal() {
        refreshTotals()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
