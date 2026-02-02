import SwiftUI

struct StatsCardsView: View {
    let stats: AggregatedStats

    var body: some View {
        HStack(spacing: 16) {
            StatsCard(
                title: "Today",
                lines: stats.today.totalLines,
                commits: stats.today.commits,
                color: .blue
            )

            StatsCard(
                title: "This Week",
                lines: stats.thisWeek.totalLines,
                commits: stats.thisWeek.commits,
                color: .green
            )

            StatsCard(
                title: "This Month",
                lines: stats.thisMonth.totalLines,
                commits: stats.thisMonth.commits,
                color: .orange
            )

            StatsCard(
                title: "All Time",
                lines: stats.totalSourceLines,
                commits: stats.total.commits,
                color: .purple
            )
        }
    }
}

struct StatsCard: View {
    let title: String
    let lines: Int
    let commits: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatNumber(lines))
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(commits)")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("commits")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

#Preview {
    StatsCardsView(stats: AggregatedStats(
        today: DailyStats(linesAdded: 500, linesRemoved: 120, commits: 5),
        thisWeek: DailyStats(linesAdded: 3500, linesRemoved: 800, commits: 28),
        thisMonth: DailyStats(linesAdded: 15000, linesRemoved: 4200, commits: 120),
        total: DailyStats(linesAdded: 150000, linesRemoved: 45000, commits: 1247),
        currentStreak: 12,
        totalSourceLines: 213000
    ))
    .padding()
    .frame(width: 900)
}
