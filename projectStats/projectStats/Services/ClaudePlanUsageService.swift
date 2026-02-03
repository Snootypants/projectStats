import Foundation
import Security

@MainActor
final class ClaudePlanUsageService: ObservableObject {
    static let shared = ClaudePlanUsageService()

    @Published var fiveHourUtilization: Double = 0
    @Published var fiveHourResetsAt: Date?
    @Published var sevenDayUtilization: Double = 0
    @Published var sevenDayResetsAt: Date?
    @Published var sonnetUtilization: Double?
    @Published var sonnetResetsAt: Date?
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var error: String?

    private var hasNotifiedHighUsage = false

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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.0.31", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            if let fiveHour = json?["five_hour"] as? [String: Any] {
                fiveHourUtilization = fiveHour["utilization"] as? Double ?? 0
                if let resetStr = fiveHour["resets_at"] as? String {
                    fiveHourResetsAt = ISO8601DateFormatter().date(from: resetStr)
                }
            }

            if let sevenDay = json?["seven_day"] as? [String: Any] {
                sevenDayUtilization = sevenDay["utilization"] as? Double ?? 0
                if let resetStr = sevenDay["resets_at"] as? String {
                    sevenDayResetsAt = ISO8601DateFormatter().date(from: resetStr)
                }
            }

            if let sonnet = json?["seven_day_sonnet"] as? [String: Any] {
                sonnetUtilization = sonnet["utilization"] as? Double
                if let resetStr = sonnet["resets_at"] as? String {
                    sonnetResetsAt = ISO8601DateFormatter().date(from: resetStr)
                }
            } else if let sonnet = json?["sonnet_only"] as? [String: Any] {
                sonnetUtilization = sonnet["utilization"] as? Double
                if let resetStr = sonnet["resets_at"] as? String {
                    sonnetResetsAt = ISO8601DateFormatter().date(from: resetStr)
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
}
