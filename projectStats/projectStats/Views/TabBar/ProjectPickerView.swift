import SwiftUI

struct ProjectPickerView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject var tabManager: TabManagerViewModel
    @State private var searchText = ""
    @State private var filterOption: ProjectFilterOption = .all

    private var filteredProjects: [Project] {
        var result = dashboardVM.projects

        // Apply filter
        switch filterOption {
        case .all: break
        case .active: result = result.filter { $0.status == .active }
        case .inProgress: result = result.filter { $0.status == .inProgress }
        case .paused: result = result.filter { $0.status == .paused }
        case .archived: result = result.filter { $0.status == .archived || $0.status == .abandoned }
        case .experimental: result = result.filter { $0.status == .experimental }
        case .dormant: result = result.filter { $0.status == .dormant }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.language?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search projects...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Picker("Filter", selection: $filterOption) {
                    ForEach(ProjectFilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)

                Spacer()
            }
            .padding(20)

            // Project grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(filteredProjects) { project in
                        ProjectPickerCard(project: project)
                            .onTapGesture {
                                tabManager.openProject(path: project.path.path)
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

/// Card used in the project picker grid
struct ProjectPickerCard: View {
    let project: Project
    @State private var isHovering = false

    private var languageColor: Color {
        switch project.language?.lowercased() {
        case "swift": return .orange
        case "javascript": return .yellow
        case "typescript": return .blue
        case "python": return .green
        case "rust": return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(languageColor)
                    .frame(width: 8, height: 8)
                Text(project.language ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if project.promptCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "text.badge.plus")
                            .font(.caption2)
                        Text("\(project.promptCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }

            // Project name
            Text(project.name)
                .font(.headline)
                .lineLimit(1)

            // Description (if available)
            if let desc = project.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(project.lastActivityString)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(project.formattedLineCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovering ? 0.08 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(isHovering ? 0.15 : 0.08), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
