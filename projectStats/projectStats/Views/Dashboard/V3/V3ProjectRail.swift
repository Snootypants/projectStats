import SwiftUI

/// V3 Project Rail - Horizontal scrolling project cards
struct V3ProjectRail: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @AppStorage("accentColorHex") private var accentColorHex: String = "#FF9500"

    private var accentColor: Color {
        Color.fromHex(accentColorHex) ?? .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Projects")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.activeProjectCount) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.homeProjects) { project in
                        V3CompactCard(project: project, accentColor: accentColor)
                            .onTapGesture {
                                openProjectInNewTab(project)
                            }
                    }
                }
                .padding(.horizontal, 24)
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

/// Compact project card for horizontal rail
private struct V3CompactCard: View {
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
        VStack(alignment: .leading, spacing: 8) {
            // Icon and status
            HStack {
                Image(systemName: project.language?.languageIcon ?? "folder.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor)

                Spacer()

                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }

            // Name
            Text(project.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            // Stats
            HStack(spacing: 8) {
                Text(project.lastActivityString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(project.formattedLineCount)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 140, height: 100)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isHovering ? accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .shadow(color: accentColor.opacity(isHovering ? 0.2 : 0.1), radius: isHovering ? 8 : 4, y: 2)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Language Icon Extension

private extension String {
    var languageIcon: String {
        switch self.lowercased() {
        case "swift": return "swift"
        case "python": return "chevron.left.forwardslash.chevron.right"
        case "javascript", "typescript": return "curlybraces"
        case "rust": return "gearshape.2"
        case "go": return "arrow.right.arrow.left"
        case "ruby": return "diamond"
        case "java", "kotlin": return "cup.and.saucer"
        case "c", "c++", "cpp": return "c.square"
        case "html", "css": return "globe"
        default: return "doc.text"
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
    V3ProjectRail()
        .environmentObject(DashboardViewModel.shared)
        .environmentObject(TabManagerViewModel.shared)
}
