import SwiftUI

struct TimeTrackingCard: View {
    @StateObject private var service = TimeTrackingService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Time Tracking")
                    .font(.headline)
                Spacer()
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(formatDuration(service.todayTotal))
                .font(.title2)

            if let project = service.currentProject {
                Text("Tracking: \(project)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Not tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

#Preview {
    TimeTrackingCard()
}
