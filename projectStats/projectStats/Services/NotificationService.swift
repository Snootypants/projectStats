import Foundation
import AppKit

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func sendNotification(title: String, message: String) {
        let settings = SettingsViewModel.shared
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = settings.playSoundOnClaudeFinished ? settings.notificationSound : nil
        NSUserNotificationCenter.default.deliver(notification)

        if settings.pushNotificationsEnabled {
            Task {
                await sendPushNotification(title: title, message: message)
            }
        }

        if settings.messagingNotificationsEnabled {
            Task {
                await MessagingService.shared.send(message: \"\\(title): \\(message)\", projectPath: TerminalOutputMonitor.shared.activeProjectPath)
            }
        }
    }

    func sendPushNotification(title: String, message: String) async {
        let settings = SettingsViewModel.shared
        guard !settings.ntfyTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        guard let url = URL(string: "https://ntfy.sh/\(settings.ntfyTopic)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.httpBody = message.data(using: .utf8)

        _ = try? await URLSession.shared.data(for: request)
    }
}
