import Foundation
import Security
import SwiftData

@MainActor
final class ClaudePlanUsageService: ObservableObject {
    static let shared = ClaudePlanUsageService()

    @Published var fiveHourUtilization: Double = 0
    @Published var fiveHourResetsAt: Date?
    @Published var sevenDayUtilization: Double = 0
    @Published var sevenDayResetsAt: Date?
    @Published var opusUtilization: Double?
    @Published var opusResetsAt: Date?
    @Published var sonnetUtilization: Double?
    @Published var sonnetResetsAt: Date?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var error: String?

    private var hasNotifiedHighUsage = false
    private var pollingTimer: Timer?
    private var lastSnapshotHour: Int = -1

    private lazy var dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    var fiveHourTimeRemaining: String {
        timeRemaining(until: fiveHourResetsAt)
    }

    var sevenDayTimeRemaining: String {
        timeRemaining(until: sevenDayResetsAt)
    }

    func fetchUsage() async {
        guard let token = getClaudeOAuthToken() else {
            error = "No Claude credentials found"
            return
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.0.32", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, compress, deflate, br", forHTTPHeaderField: "Accept-Encoding")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                self.error = "HTTP \(httpResponse.statusCode): \(body)"
                return
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // API returns utilization as percentage (0-100), convert to decimal (0-1)
            if let fiveHour = json?["five_hour"] as? [String: Any] {
                let rawUtilization = fiveHour["utilization"] as? Double ?? 0
                fiveHourUtilization = rawUtilization / 100.0
                if let resetStr = fiveHour["resets_at"] as? String {
                    fiveHourResetsAt = parseDate(resetStr)
                }
            }

            if let sevenDay = json?["seven_day"] as? [String: Any] {
                let rawUtilization = sevenDay["utilization"] as? Double ?? 0
                sevenDayUtilization = rawUtilization / 100.0
                if let resetStr = sevenDay["resets_at"] as? String {
                    sevenDayResetsAt = parseDate(resetStr)
                }
            }

            if let opus = json?["seven_day_opus"] as? [String: Any] {
                let rawUtilization = opus["utilization"] as? Double
                opusUtilization = rawUtilization.map { $0 / 100.0 }
                if let resetStr = opus["resets_at"] as? String {
                    opusResetsAt = parseDate(resetStr)
                }
            } else {
                opusUtilization = nil
                opusResetsAt = nil
            }

            // Check for sonnet-specific limits
            if let sonnet = json?["seven_day_sonnet"] as? [String: Any] {
                let rawUtilization = sonnet["utilization"] as? Double
                sonnetUtilization = rawUtilization.map { $0 / 100.0 }
                if let resetStr = sonnet["resets_at"] as? String {
                    sonnetResetsAt = parseDate(resetStr)
                }
            } else {
                sonnetUtilization = nil
                sonnetResetsAt = nil
            }

            lastUpdated = Date()
            error = nil

            if SettingsViewModel.shared.notifyPlanUsageHigh {
                if fiveHourUtilization >= 0.75, !hasNotifiedHighUsage {
                    let percent = Int(fiveHourUtilization * 100)
                    NotificationService.shared.sendNotification(
                        title: "Plan usage high",
                        message: "Claude usage is at \(percent)% of the 5h window."
                    )
                    hasNotifiedHighUsage = true
                }

                if fiveHourUtilization < 0.6 {
                    hasNotifiedHighUsage = false
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func parseDate(_ string: String) -> Date? {
        // Try with fractional seconds first
        if let date = dateFormatter.date(from: string) {
            return date
        }
        // Fallback to standard ISO8601 without fractional seconds
        let fallback = ISO8601DateFormatter()
        return fallback.date(from: string)
    }

    private func timeRemaining(until resetDate: Date?) -> String {
        guard let resetDate else { return "--" }
        let interval = resetDate.timeIntervalSinceNow
        if interval <= 0 { return "Now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func getClaudeOAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }

        return token
    }

    // MARK: - Hourly Polling

    func startHourlyPolling() {
        // Initial fetch
        Task {
            await fetchUsage()
            await saveSnapshotIfNewHour()
        }

        // Poll every 10 minutes
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchUsage()
                await self?.saveSnapshotIfNewHour()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func saveSnapshotIfNewHour() async {
        let currentHour = Calendar.current.component(.hour, from: Date())

        guard currentHour != lastSnapshotHour else { return }
        guard lastUpdated != nil else { return }

        lastSnapshotHour = currentHour

        let snapshot = ClaudePlanUsageSnapshot(
            fiveHourUtilization: fiveHourUtilization,
            fiveHourResetsAt: fiveHourResetsAt,
            sevenDayUtilization: sevenDayUtilization,
            sevenDayResetsAt: sevenDayResetsAt,
            opusUtilization: opusUtilization,
            opusResetsAt: opusResetsAt,
            sonnetUtilization: sonnetUtilization,
            sonnetResetsAt: sonnetResetsAt
        )

        let context = AppModelContainer.shared.mainContext
        context.insert(snapshot)
        try? context.save()

        print("[ClaudePlanUsage] Hourly snapshot saved: 5h=\(Int(fiveHourUtilization * 100))%")
    }

    func saveSnapshotNow() async {
        guard lastUpdated != nil else { return }

        let snapshot = ClaudePlanUsageSnapshot(
            fiveHourUtilization: fiveHourUtilization,
            fiveHourResetsAt: fiveHourResetsAt,
            sevenDayUtilization: sevenDayUtilization,
            sevenDayResetsAt: sevenDayResetsAt,
            opusUtilization: opusUtilization,
            opusResetsAt: opusResetsAt,
            sonnetUtilization: sonnetUtilization,
            sonnetResetsAt: sonnetResetsAt
        )

        let context = AppModelContainer.shared.mainContext
        context.insert(snapshot)
        try? context.save()
    }

    func getSnapshots(since date: Date) -> [ClaudePlanUsageSnapshot] {
        let context = AppModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<ClaudePlanUsageSnapshot>(
            predicate: #Predicate { $0.capturedAt >= date },
            sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func getTodaySnapshots() -> [ClaudePlanUsageSnapshot] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return getSnapshots(since: startOfDay)
    }
}
