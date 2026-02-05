import SwiftUI

/// V5 Game Cards - Project cards with star ratings and progress bars
struct V5GameCards: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(viewModel.homeProjects) { project in
                GameCard(project: project, accentColor: accentColor)
                    .onTapGesture {
                        openProjectInNewTab(project)
                    }
            }
        }
    }

    private func openProjectInNewTab(_ project: Project) {
        let path = project.path.path
        if let existingTab = tabManager.tabs.first(where: {
            if case .projectWorkspace(let p) = $0.content { return p == path }
            return false
        }) {
            tabManager.selectTab(existingTab.id)
        } else {
            tabManager.newTab()
            tabManager.openProject(path: path)
        }
    }
}

// MARK: - Game Card

private struct GameCard: View {
    let project: Project
    let accentColor: Color
    @State private var isHovering = false

    // Calculate stars based on activity (1-5)
    private var activityStars: Int {
        switch project.status {
        case .active: return 5
        case .inProgress: return 4
        case .experimental: return 3
        case .paused: return 2
        case .dormant, .archived, .abandoned: return 1
        }
    }

    // Calculate progress based on recent activity
    private var activityProgress: Double {
        // Use time since last commit as a proxy
        guard let lastCommitDate = project.lastCommit?.date else { return 0.2 }
        let hoursSince = Date().timeIntervalSince(lastCommitDate) / 3600
        if hoursSince < 1 { return 1.0 }
        if hoursSince < 24 { return 0.8 }
        if hoursSince < 72 { return 0.6 }
        if hoursSince < 168 { return 0.4 }
        return 0.2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stars
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= activityStars ? "star.fill" : "star")
                        .foregroundStyle(star <= activityStars ? .yellow : .gray.opacity(0.3))
                        .font(.caption2)
                }
                Spacer()
            }

            // Name
            Text(project.name)
                .font(.caption.bold())
                .lineLimit(1)

            // Line count
            Text(project.formattedLineCount)
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Last active
            Text(project.lastActivityString)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: geo.size.width * activityProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isHovering ? accentColor.opacity(0.4) : Color.clear, lineWidth: 2)
        )
        .shadow(color: isHovering ? accentColor.opacity(0.3) : Color.clear, radius: 8)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
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
    V5GameCards()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(TabManagerViewModel.shared)
        .padding()
}
