import Foundation
import UserNotifications
import AppKit

final class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    private override init() {
        super.init()
        requestAuthorization()
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[Notifications] Authorization granted")
            } else if let error = error {
                print("[Notifications] Authorization error: \(error)")
            }
        }

        UNUserNotificationCenter.current().delegate = self
    }

    func sendNotification(title: String, message: String, sound: Bool = true) {
        print("[Notifications] Attempting to send: \(title) - \(message)")

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message

        let settings = SettingsViewModel.shared
        if sound, settings.playSoundOnClaudeFinished {
            // Use the configured sound name
            content.sound = UNNotificationSound(named: UNNotificationSoundName(settings.notificationSound))
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Error sending: \(error)")
            } else {
                print("[Notifications] Sent successfully: \(title)")
            }
        }

        // Also send to external services if enabled
        if settings.pushNotificationsEnabled {
            Task {
                await sendPushNotification(title: title, message: message)
            }
        }

        if settings.messagingNotificationsEnabled {
            Task {
                await MessagingService.shared.send(
                    message: "\(title): \(message)",
                    projectPath: TerminalOutputMonitor.shared.activeProjectPath
                )
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

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground (but tab not active)
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // User tapped notification - bring app to front
        NSApp.activate(ignoringOtherApps: true)
        completionHandler()
    }
}
