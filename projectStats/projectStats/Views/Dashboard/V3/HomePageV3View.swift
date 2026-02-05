import SwiftUI

/// Home Page V3 - Command Center Layout
/// Dense 3-column systems dashboard with graph as centerpiece
struct HomePageV3View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("V3 Command Center")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.secondary)
                Text("Coming soon - Dense 3-column systems dashboard")
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }
}

#Preview {
    HomePageV3View()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(SettingsViewModel.shared)
}
