import SwiftUI

/// V4 Project Footer - Compact project cards in a grid
struct V4ProjectFooter: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.homeProjects.prefix(8)) { project in
                    V4CompactProjectCard(project: project, accentColor: accentColor)
                        .onTapGesture {
                            openProjectInNewTab(project)
                        }
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

// MARK: - Compact Project Card

private struct V4CompactProjectCard: View {
    let project: Project
    let accentColor: Color
    @State private var isHovering = false

    private var statusColor: Color {
        switch project.status {
        case .active: return .green
        case .inProgress: return .yellow
        case .dormant: return .gray
        case .paused: return .yellow
        case .experimental: return .blue
        case .archived: return .gray
        case .abandoned: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.caption.bold())
                    .lineLimit(1)

                Text(project.lastActivityString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHovering ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isHovering)
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
    V4ProjectFooter()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(TabManagerViewModel.shared)
        .padding()
}
