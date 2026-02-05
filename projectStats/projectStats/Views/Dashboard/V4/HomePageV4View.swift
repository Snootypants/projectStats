import SwiftUI

/// Home Page V4 - Timeline Layout
/// Week-as-story with vertical heatmap and annotation chips
struct HomePageV4View: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Main content: Vertical heatmap + Annotated Chart
                HStack(alignment: .top, spacing: 0) {
                    // LEFT - Vertical Heatmap
                    V4VerticalHeatmap()
                        .frame(width: 100)

                    // CENTER/RIGHT - Main Chart with annotations
                    V4AnnotatedChart()
                        .padding(24)
                }

                Divider()

                // Time period cards
                V4TimeCards()
                    .padding(24)

                Divider()

                // Project footer
                V4ProjectFooter()
                    .padding(24)
            }
        }
        .background(Color.primary.opacity(0.02))
    }
}

#Preview {
    HomePageV4View()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(SettingsViewModel.shared)
}
