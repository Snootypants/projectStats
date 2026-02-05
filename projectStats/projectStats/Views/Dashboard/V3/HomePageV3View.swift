import SwiftUI

/// Home Page V3 - Command Center Layout
/// Dense 3-column systems dashboard with graph as centerpiece
struct HomePageV3View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // TOP BAR - XP, Streak, Session Active
                V3TopBar()

                // HERO STRIP - Today's time, You/Claude split, API spend
                V3HeroStrip()

                // 3-COLUMN CORE
                V3ThreeColumnCore()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)

                // BOTTOM RAIL - Horizontal scrolling project cards
                V3ProjectRail()
                    .padding(.bottom, 24)
            }
        }
        .background(Color.primary.opacity(0.02))
    }
}

#Preview {
    HomePageV3View()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(SettingsViewModel.shared)
}
