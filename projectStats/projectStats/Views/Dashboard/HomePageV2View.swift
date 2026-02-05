import SwiftUI

/// Home Page V2 - Refined layout with grouped stats, galaxy time display, and enhanced charts
/// This is the container view that assembles all V2 components
struct HomePageV2View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Placeholder - V2 components will be added in subsequent parts
                Text("Home Page V2")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.secondary)

                Text("Coming soon: Grouped stats, galaxy layout, enhanced charts")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    HomePageV2View()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(SettingsViewModel.shared)
}
