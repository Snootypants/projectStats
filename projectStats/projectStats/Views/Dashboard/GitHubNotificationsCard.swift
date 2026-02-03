import SwiftUI

struct GitHubNotificationsCard: View {
    @StateObject private var service = GitHubService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("GitHub")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task { await service.fetchNotifications() }
                }
                .font(.caption)
            }

            if service.notifications.isEmpty {
                Text("No notifications")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(service.notifications.prefix(3)) { notification in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.subject.title)
                            .font(.subheadline)
                        Text(notification.repository.fullName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(minHeight: 140, alignment: .topLeading)
        .background(.background)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1))
        )
        .task { await service.fetchNotifications() }
    }
}

#Preview {
    GitHubNotificationsCard()
}
