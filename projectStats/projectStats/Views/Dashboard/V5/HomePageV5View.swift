import SwiftUI

/// Home Page V5 - Arcade HUD Layout
/// Gamified stats with XP front-and-center
struct HomePageV5View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // TOP - XP Header with level and streak
                V5XPHeader()

                // MIDDLE - Two panel layout
                HStack(alignment: .top, spacing: 20) {
                    // LEFT - Active Session
                    V5SessionPanel()
                        .frame(maxWidth: .infinity)

                    // RIGHT - Money Burn
                    V5MoneyPanel()
                        .frame(maxWidth: .infinity)
                }

                // CENTER - Project Activity
                V5ProjectActivity()

                // BOTTOM - Game-like project cards
                V5GameCards()
            }
            .padding(24)
        }
        .background(Color.primary.opacity(0.02))
    }
}

#Preview {
    HomePageV5View()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(SettingsViewModel.shared)
}
