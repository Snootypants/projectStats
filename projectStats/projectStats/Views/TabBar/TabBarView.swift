import Foundation
import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var tabManager: TabManagerViewModel
    @EnvironmentObject var dashboardVM: DashboardViewModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(displayTabs) { tab in
                        TabBarItem(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabID,
                            isFavorite: tabManager.isFavorite(tab),
                            project: projectForTab(tab),
                            projects: dashboardVM.projects,
                            onSelect: { tabManager.selectTab(tab.id) },
                            onClose: { tabManager.closeTab(tab.id) },
                            onToggleFavorite: { tabManager.toggleFavorite(tab) },
                            onDuplicate: { duplicateTab(tab) },
                            onCloseOthers: { tabManager.closeOtherTabs(keeping: tab.id) }
                        )
                        .draggable(tab.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let draggedIdString = items.first,
                                  let draggedId = UUID(uuidString: draggedIdString) else { return false }
                            tabManager.moveTab(from: draggedId, to: tab.id)
                            return true
                        }
                    }
                }
            }

            Button {
                tabManager.newTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Tab (Cmd+Shift+T)")
            .padding(.horizontal, 4)

            Spacer()

            HStack(spacing: 8) {
                SettingsLink {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
    }

    private var displayTabs: [AppTab] {
        let pinned = tabManager.tabs.filter { $0.isPinned }
        let others = tabManager.tabs.filter { !$0.isPinned }
        let favorites = others.filter { tabManager.isFavorite($0) }
        let nonFavorites = others.filter { !tabManager.isFavorite($0) }
        return pinned + favorites + nonFavorites
    }

    private func projectForTab(_ tab: AppTab) -> Project? {
        guard case .projectWorkspace(let path) = tab.content else { return nil }
        return dashboardVM.projects.first { $0.path.path == path }
    }

    private func duplicateTab(_ tab: AppTab) {
        guard case .projectWorkspace(let path) = tab.content else { return }
        tabManager.newTab()
        tabManager.openProject(path: path)
    }

}

struct TabBarItem: View {
    let tab: AppTab
    let isActive: Bool
    let isFavorite: Bool
    let project: Project?
    let projects: [Project]
    let onSelect: () -> Void
    let onClose: () -> Void
    let onToggleFavorite: () -> Void
    let onDuplicate: () -> Void
    let onCloseOthers: () -> Void

    @State private var isHovering = false
    @State private var isCloseHovering = false
    @State private var showTooltip = false
    @State private var tooltipTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? .primary : .secondary)

            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)

            if case .projectWorkspace = tab.content {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 10))
                        .foregroundStyle(isFavorite ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
                }
                .buttonStyle(.plain)
            }

            if tab.isCloseable {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isCloseHovering ? .primary : .tertiary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                        .background(isCloseHovering ? Color.primary.opacity(0.1) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
                .onHover { isCloseHovering = $0 }
                .opacity(isHovering || isActive ? 1 : 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            TabShape(cornerRadius: 6)
                .fill(isActive ? Color(nsColor: .windowBackgroundColor) : Color.primary.opacity(0.04))
        )
        .overlay(
            TabShape(cornerRadius: 6)
                .stroke(Color.primary.opacity(isActive ? 0.15 : 0.05), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
            handleTooltip(hovering: hovering)
        }
        .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
            if let project {
                ProjectTabTooltip(project: project, isFavorite: isFavorite)
                    .frame(width: 240)
                    .padding(8)
            }
        }
        .help(pickerTooltip)
        .contextMenu {
            if case .projectWorkspace = tab.content {
                Button(isFavorite ? "Unfavorite" : "Favorite") { onToggleFavorite() }
                Divider()
                Button("Duplicate Tab") { onDuplicate() }
                Button("Close Tab") { onClose() }
                Button("Close Other Tabs") { onCloseOthers() }
            } else {
                Button("Close Tab") { onClose() }
            }
        }
    }

    private var pickerTooltip: String {
        guard case .projectPicker = tab.content else { return "" }
        let count = projects.count
        if count == 0 { return "No projects" }
        let recent = projects
            .sorted { ($0.lastCommit?.date ?? .distantPast) > ($1.lastCommit?.date ?? .distantPast) }
            .prefix(3)
            .map(\.name)
        return "Projects: \(count)\nRecent: \(recent.joined(separator: ", "))"
    }

    private func handleTooltip(hovering: Bool) {
        tooltipTask?.cancel()
        if hovering, project != nil {
            tooltipTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if !Task.isCancelled {
                    showTooltip = true
                }
            }
        } else {
            showTooltip = false
        }
    }
}

private struct TabShape: Shape {
    var cornerRadius: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(cornerRadius, rect.height / 2)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private struct ProjectTabTooltip: View {
    let project: Project
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.system(size: 12, weight: .semibold))

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                Text("\(project.lineCount.formatted()) lines")
            }
            .font(.system(size: 11))

            if let commits = project.totalCommits {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                    Text("\(commits.formatted()) commits")
                }
                .font(.system(size: 11))
            }

            if let commit = project.lastCommit {
                HStack(spacing: 6) {
                    Image(systemName: "hammer")
                    Text("\(commit.shortHash) (\(commit.date.relativeString))")
                }
                .font(.system(size: 11))
            }

            if let language = project.language {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                    Text(language)
                }
                .font(.system(size: 11))
            }

            if isFavorite {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                    Text("Favorited")
                }
                .font(.system(size: 11))
            }
        }
    }
}
