import SwiftUI
import SwiftData

struct SessionSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var summary: DailySummary?
    @State private var isLoading = true
    @State private var selectedDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Summary")
                    .font(.headline)

                Spacer()

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: selectedDate) { _, _ in
                        loadSummary()
                    }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let summary {
                summaryContent(summary)
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .task {
            loadSummary()
        }
    }

    @ViewBuilder
    private func summaryContent(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stats row
            HStack(spacing: 24) {
                statCard(title: "Commits", value: "\(summary.totalCommits)", icon: "arrow.triangle.branch")
                statCard(title: "Time", value: formatTime(summary.timeSpentMinutes), icon: "clock")
                statCard(title: "Tokens", value: formatTokens(summary.claudeTokensUsed), icon: "cpu")
                statCard(title: "Cost", value: "$\(String(format: "%.2f", summary.claudeCost))", icon: "dollarsign.circle")
            }

            // Projects
            if !summary.projectsWorkedOn.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projects")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        ForEach(summary.projectsWorkedOn, id: \.self) { project in
                            Text(project)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Highlights
            if !summary.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Highlights")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(summary.highlights, id: \.self) { highlight in
                        HStack(spacing: 4) {
                            Image(systemName: "sparkle")
                                .foregroundStyle(.yellow)
                            Text(highlight)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h\(minutes % 60)m"
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1000000 {
            return "\(tokens / 1000000)M"
        } else if tokens >= 1000 {
            return "\(tokens / 1000)k"
        }
        return "\(tokens)"
    }

    private func loadSummary() {
        isLoading = true
        Task {
            summary = await SessionSummaryService.shared.generateDailySummary(
                for: selectedDate,
                context: modelContext
            )
            isLoading = false
        }
    }
}

#Preview {
    SessionSummaryView()
        .frame(width: 400)
}
