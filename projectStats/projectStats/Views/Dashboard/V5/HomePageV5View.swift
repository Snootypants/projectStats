import SwiftUI

/// Home Page V5 - Arcade HUD Layout
/// Gamified stats with XP front-and-center
struct HomePageV5View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("V5 Arcade HUD")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.secondary)
                Text("Coming soon - Gamified stats with XP front-and-center")
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }
}

#Preview {
    HomePageV5View()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(SettingsViewModel.shared)
}
