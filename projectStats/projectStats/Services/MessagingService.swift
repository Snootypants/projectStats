import Foundation
import SwiftData

enum MessagingServiceType: String, CaseIterable, Codable {
    case telegram
    case slack
    case discord
    case ntfy

    var displayName: String {
        switch self {
        case .telegram: return "Telegram"
        case .slack: return "Slack"
        case .discord: return "Discord"
        case .ntfy: return "ntfy"
        }
    }
}

struct IncomingMessage: Identifiable {
    var id: String
    var text: String
    var timestamp: Date
    var sender: String?
}

protocol MessagingProvider {
    func send(message: String) async throws
    func poll() async throws -> [IncomingMessage]
}

@MainActor
final class MessagingService: ObservableObject {
    static let shared = MessagingService()

    @Published var lastError: String?
    @Published var lastPollAt: Date?
    @Published var lastSendAt: Date?

    private var pollTimer: Timer?

    private init() {
        startPollingIfNeeded()
    }

    func startPollingIfNeeded() {
        pollTimer?.invalidate()
        guard SettingsViewModel.shared.remoteCommandsEnabled else { return }
        let interval = max(10, SettingsViewModel.shared.remoteCommandsInterval)
        pollTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            Task { await self?.pollRemoteCommands() }
        }
    }

    func send(message: String, projectPath: String? = nil) async {
        guard SettingsViewModel.shared.messagingNotificationsEnabled else { return }
        guard let provider = makeProvider() else { return }

        do {
            try await provider.send(message: message)
            lastSendAt = Date()
            saveMessage(direction: "outgoing", text: message, projectPath: projectPath)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func pollRemoteCommands() async {
        guard SettingsViewModel.shared.remoteCommandsEnabled else { return }
        guard let provider = makeProvider() else { return }

        do {
            let messages = try await provider.poll()
            lastPollAt = Date()
            lastError = nil
            for message in messages {
                saveMessage(direction: "incoming", text: message.text, projectPath: nil)
                await handleRemoteCommand(message.text)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func makeProvider() -> MessagingProvider? {
        let settings = SettingsViewModel.shared
        switch settings.messagingServiceType {
        case .telegram:
            guard !settings.telegramBotToken.isEmpty, !settings.telegramChatId.isEmpty else { return nil }
            return TelegramProvider(token: settings.telegramBotToken, chatId: settings.telegramChatId)
        case .slack:
            guard !settings.slackWebhookURL.isEmpty else { return nil }
            return SlackProvider(webhookURL: settings.slackWebhookURL)
        case .discord:
            guard !settings.discordWebhookURL.isEmpty else { return nil }
            return DiscordProvider(webhookURL: settings.discordWebhookURL)
        case .ntfy:
            guard !settings.messagingNtfyTopic.isEmpty else { return nil }
            return NtfyProvider(topic: settings.messagingNtfyTopic)
        }
    }

    private func saveMessage(direction: String, text: String, projectPath: String?) {
        let context = AppModelContainer.shared.mainContext
        let message = ChatMessage(
            service: SettingsViewModel.shared.messagingServiceType.rawValue,
            direction: direction,
            text: text,
            timestamp: Date(),
            projectPath: projectPath,
            handled: direction == "incoming"
        )
        context.insert(message)
        context.safeSave()
    }

    private func handleRemoteCommand(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parts = trimmed.split(separator: " ")
        guard let command = parts.first?.lowercased() else { return }
        let args = parts.dropFirst().map { String($0) }

        switch command {
        case "status":
            let activePath = TerminalOutputMonitor.shared.activeProjectPath
            let activeName = DashboardViewModel.shared.projects.first { $0.path.path == activePath }?.name ?? "None"
            let message = "Status: active project = \(activeName). Projects tracked = \(DashboardViewModel.shared.projects.count)."
            await send(message: message)

        case "usage":
            let usage = Int(ClaudePlanUsageService.shared.fiveHourUtilization * 100)
            let message = "Claude usage: \(usage)% of 5h window. Resets in \(ClaudePlanUsageService.shared.fiveHourTimeRemaining)."
            await send(message: message)

        case "servers":
            await send(message: "Running servers: not yet wired globally.")

        case "kill":
            await send(message: "Kill command not implemented in this build.")

        case "today":
            let hours = TimeTrackingService.shared.todayTotal / 3600
            await send(message: String(format: "Time tracked today: %.1fh", hours))

        case "notify":
            if let toggle = args.first?.lowercased() {
                if toggle == "on" {
                    SettingsViewModel.shared.messagingNotificationsEnabled = true
                    await send(message: "Notifications enabled.")
                } else if toggle == "off" {
                    SettingsViewModel.shared.messagingNotificationsEnabled = false
                    await send(message: "Notifications disabled.")
                }
            }

        default:
            await send(message: "Unknown command: \(command)")
        }
    }
}
