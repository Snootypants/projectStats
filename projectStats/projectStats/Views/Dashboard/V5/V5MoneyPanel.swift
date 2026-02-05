import SwiftUI

/// V5 Money Panel - API spend, usage meters, efficiency score
struct V5MoneyPanel: View {
    @StateObject private var usageService = ClaudeUsageService.shared
    @StateObject private var planUsage = ClaudePlanUsageService.shared
    @EnvironmentObject var viewModel: DashboardViewModel
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    // Calculate cost per commit
    private var costPerCommit: Double {
        let totalCost = usageService.globalTodayStats?.totalCost ?? 0
        let commits = viewModel.aggregatedStats.today.commits
        guard commits > 0 else { return 0 }
        return totalCost / Double(commits)
    }

    // Calculate efficiency as stars (1-5)
    private var efficiencyStars: Int {
        // Lower cost per commit = better efficiency
        // $0-0.10 = 5 stars, $0.10-0.25 = 4 stars, $0.25-0.50 = 3 stars, $0.50-1.00 = 2 stars, $1.00+ = 1 star
        if costPerCommit <= 0.10 { return 5 }
        if costPerCommit <= 0.25 { return 4 }
        if costPerCommit <= 0.50 { return 3 }
        if costPerCommit <= 1.00 { return 2 }
        return 1
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.yellow)
                Text("MONEY BURN")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Big cost display
            Text(String(format: "$%.2f", usageService.globalTodayStats?.totalCost ?? 0))
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Text("today")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Usage meters
            VStack(spacing: 8) {
                usageMeter(label: "Session", value: planUsage.fiveHourUtilization)
                usageMeter(label: "Weekly", value: planUsage.sevenDayUtilization)
            }

            Divider()

            // Efficiency Score
            VStack(spacing: 4) {
                Text("EFFICIENCY SCORE")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= efficiencyStars ? "star.fill" : "star")
                            .foregroundStyle(star <= efficiencyStars ? .yellow : .gray.opacity(0.3))
                    }
                }
                .font(.title2)

                if costPerCommit > 0 {
                    Text(String(format: "$%.2f / commit", costPerCommit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await planUsage.fetchUsage()
        }
    }

    private func usageMeter(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usageColor(value))
                        .frame(width: max(4, geo.size.width * min(value, 1)))
                }
            }
            .frame(height: 8)
        }
    }

    private func usageColor(_ value: Double) -> Color {
        if value > 0.8 { return .red }
        if value > 0.6 { return .orange }
        return accentColor
    }
}

// MARK: - Color Hex Extension

private extension Color {
    static func fromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255

        return Color(red: r, green: g, blue: b)
    }
}

#Preview {
    V5MoneyPanel()
        .environmentObject(DashboardViewModel.shared)
        .frame(width: 300)
        .padding()
}
