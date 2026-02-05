import SwiftUI

/// Home Page V4 - Timeline Layout
/// Week-as-story with vertical heatmap and annotation chips
struct HomePageV4View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("V4 Timeline")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.secondary)
                Text("Coming soon - Week-as-story with vertical heatmap")
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }
}

#Preview {
    HomePageV4View()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(SettingsViewModel.shared)
}
