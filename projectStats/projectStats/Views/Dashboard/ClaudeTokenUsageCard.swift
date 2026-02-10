import SwiftUI

// MARK: - DORMANT — Not wired to any view hierarchy.
// Claude token usage card defined but never integrated into dashboard.
// Do NOT maintain or update until activated.
// To activate: remove this marker, add to a dashboard view.

struct ClaudeTokenUsageCard: View {
    @ObservedObject var usageService = ClaudeUsageService.shared
    var projectPath: String? = nil  // nil = show global stats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(projectPath != nil ? "Project Usage" : "Claude Code Usage")
                    .font(.headline)
                Spacer()
                if usageService.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button {
                        Task {
                            if let path = projectPath {
                                await usageService.refreshProject(path)
                            } else {
                                await usageService.refreshGlobal()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if let error = usageService.lastError, projectPath == nil {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                // Today's stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(todayFormatted)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                }

                Divider()

                // Week stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last 7 Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(weekFormatted)
                        .font(.system(size: 16, design: .rounded))
                }

                // Mini bar chart
                if !weekStats.isEmpty {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(weekStats.prefix(7).reversed()) { stat in
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor.opacity(0.7))
                                    .frame(width: 20, height: barHeight(for: stat))
                                Text(dayLabel(stat.date))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 60)
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
        .onAppear {
            Task {
                if let path = projectPath {
                    await usageService.refreshProjectIfNeeded(path)
                } else {
                    await usageService.refreshGlobalIfNeeded()
                }
            }
        }
    }

    private var todayFormatted: String {
        if let path = projectPath {
            return usageService.projectTodayFormatted(path)
        }
        return usageService.globalTodayFormatted()
    }

    private var weekFormatted: String {
        if let path = projectPath {
            return usageService.projectWeekFormatted(path)
        }
        return usageService.globalWeekFormatted()
    }

    private var weekStats: [ClaudeUsageService.DailyUsageStats] {
        if let path = projectPath {
            return usageService.projectStats[path]?.weekStats ?? []
        }
        return usageService.globalWeekStats
    }

    private func barHeight(for stat: ClaudeUsageService.DailyUsageStats) -> CGFloat {
        let maxTokens = weekStats.map { $0.totalTokens }.max() ?? 1
        guard maxTokens > 0 else { return 4 }
        let ratio = Double(stat.totalTokens) / Double(maxTokens)
        return CGFloat(ratio * 40) + 4
    }

    private func dayLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return String(dayFormatter.string(from: date).prefix(1))
    }
}
