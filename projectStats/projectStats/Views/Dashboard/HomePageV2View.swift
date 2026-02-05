import SwiftUI

/// Home Page V2 - Refined layout with grouped stats, galaxy time display, and enhanced charts
/// This is the container view that assembles all V2 components
struct HomePageV2View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Stats Pills Row - Grouped by type
                V2StatsRow()

                // Galaxy Layout - Time center, usage bars flanking
                V2GalaxyLayout()

                // Activity Chart with time range and data toggles
                V2ChartView()

                // Placeholder for remaining V2 components
                Text("Coming soon: Project cards")
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
