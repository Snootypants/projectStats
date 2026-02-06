import SwiftUI

struct CompactLockoutBar: View {
    @ObservedObject var usageService = ClaudePlanUsageService.shared

    private var fillPercentage: CGFloat {
        CGFloat(max(usageService.fiveHourUtilization, usageService.sevenDayUtilization))
    }

    private var sessionPercent: Int {
        Int(usageService.fiveHourUtilization * 100)
    }

    private var weeklyPercent: Int {
        Int(usageService.sevenDayUtilization * 100)
    }

    private var lockoutGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .purple, .pink],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 4)
                    .fill(lockoutGradient)
                    .frame(width: geo.size.width * fillPercentage)
            }
        }
        .frame(height: 8)
        .help("Session: \(sessionPercent)% • Weekly: \(weeklyPercent)%")
    }
}
