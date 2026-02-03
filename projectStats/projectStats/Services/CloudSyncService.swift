import Foundation
import SwiftUI
import SwiftData

struct SyncPayload: Codable {
    let deviceId: String
    let timestamp: Date
    let projects: [ProjectSnapshot]
    let timeTracking: [TimeEntryDTO]
    let chatMessages: [ChatMessageDTO]
    let claudeUsage: [UsageSnapshot]
    let achievements: [AchievementDTO]
}

struct ProjectSnapshot: Codable {
    let path: String
    let name: String
    let language: String?
    let lineCount: Int
    let fileCount: Int
    let commitCount: Int
    let lastCommit: String
    let lastCommitDate: Date?
    let promptCount: Int
    let workLogCount: Int
}

struct TimeEntryDTO: Codable {
    let projectPath: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let isManual: Bool
    let notes: String?
}

struct ChatMessageDTO: Codable {
    let service: String
    let direction: String
    let text: String
    let timestamp: Date
    let projectPath: String?
}

struct UsageSnapshot: Codable {
    let timestamp: Date
    let fiveHourUtilization: Double
    let sevenDayUtilization: Double
}

struct AchievementDTO: Codable {
    let key: String
    let unlockedAt: Date
    let projectPath: String?
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case error(String)
}

@MainActor
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    @AppStorage("sync.endpoint") var endpoint: String = ""
    @AppStorage("sync.apiKey") var apiKey: String = ""
    @AppStorage("sync.include.chat") var includeChatMessages: Bool = true
    @AppStorage("sync.include.projects") var includeProjectStats: Bool = true
    @AppStorage("sync.include.usage") var includeClaudeUsage: Bool = true
    @AppStorage("sync.include.time") var includeTimeTracking: Bool = true
    @AppStorage("sync.include.achievements") var includeAchievements: Bool = true
    @AppStorage("sync.frequencyMinutes") var syncFrequencyMinutes: Int = 60

    @Published var lastSync: Date?
    @Published var syncStatus: SyncStatus = .idle

    private var timer: Timer?

    private init() {
        startTimerIfNeeded()
    }

    func startTimerIfNeeded() {
        timer?.invalidate()
        guard syncFrequencyMinutes > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(syncFrequencyMinutes * 60), repeats: true) { [weak self] _ in
            Task { await self?.sync() }
        }
    }

    func sync() async {
        guard !endpoint.isEmpty, !apiKey.isEmpty else { return }

        syncStatus = .syncing
        let payload = buildPayload()

        guard let url = URL(string: endpoint) else {
            syncStatus = .error("Invalid endpoint")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 200 {
                lastSync = Date()
                syncStatus = .success
            } else {
                syncStatus = .error("Sync failed")
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    private func buildPayload() -> SyncPayload {
        let deviceId = Host.current().localizedName ?? UUID().uuidString
        let projects = includeProjectStats ? DashboardViewModel.shared.projects.map { project in
            ProjectSnapshot(
                path: project.path.path,
                name: project.name,
                language: project.language,
                lineCount: project.lineCount,
                fileCount: project.fileCount,
                commitCount: project.totalCommits ?? 0,
                lastCommit: project.lastCommit?.message ?? "",
                lastCommitDate: project.lastCommit?.date,
                promptCount: project.promptCount,
                workLogCount: project.workLogCount
            )
        } : []

        let context = AppModelContainer.shared.mainContext
        let entries: [TimeEntry] = (try? context.fetch(FetchDescriptor<TimeEntry>())) ?? []
        let chatMessages: [ChatMessage] = (try? context.fetch(FetchDescriptor<ChatMessage>())) ?? []
        let achievements: [AchievementUnlock] = (try? context.fetch(FetchDescriptor<AchievementUnlock>())) ?? []

        let timeTracking = includeTimeTracking ? entries.map {
            TimeEntryDTO(
                projectPath: $0.projectPath,
                startTime: $0.startTime,
                endTime: $0.endTime,
                duration: $0.duration,
                isManual: $0.isManual,
                notes: $0.notes
            )
        } : []

        let messages = includeChatMessages ? chatMessages.map {
            ChatMessageDTO(
                service: $0.service,
                direction: $0.direction,
                text: $0.text,
                timestamp: $0.timestamp,
                projectPath: $0.projectPath
            )
        } : []

        let usageSnapshots = includeClaudeUsage ? [
            UsageSnapshot(
                timestamp: Date(),
                fiveHourUtilization: ClaudePlanUsageService.shared.fiveHourUtilization,
                sevenDayUtilization: ClaudePlanUsageService.shared.sevenDayUtilization
            )
        ] : []

        let achievementDTOs = includeAchievements ? achievements.map {
            AchievementDTO(key: $0.key, unlockedAt: $0.unlockedAt, projectPath: $0.projectPath)
        } : []

        return SyncPayload(
            deviceId: deviceId,
            timestamp: Date(),
            projects: projects,
            timeTracking: timeTracking,
            chatMessages: messages,
            claudeUsage: usageSnapshots,
            achievements: achievementDTOs
        )
    }
}
