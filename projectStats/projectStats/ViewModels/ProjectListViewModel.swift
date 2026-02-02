import Foundation
import SwiftUI

enum ProjectSortOption: String, CaseIterable {
    case recent = "Recent"
    case mostActive = "Most Active"
    case alphabetical = "Alphabetical"
    case byLanguage = "By Language"
    case byLines = "By Lines"
}

enum ProjectFilterOption: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case inProgress = "In Progress"
    case dormant = "Dormant"
    case paused = "Paused"
    case experimental = "Experimental"
    case archived = "Archived"
}

@MainActor
class ProjectListViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var sortOption: ProjectSortOption = .recent
    @Published var filterOption: ProjectFilterOption = .all
    @Published var selectedProject: Project?

    private var allProjects: [Project] = []

    var filteredProjects: [Project] {
        var result = allProjects

        // Apply filter
        switch filterOption {
        case .all:
            break
        case .active:
            result = result.filter { $0.status == .active }
        case .inProgress:
            result = result.filter { $0.status == .inProgress }
        case .dormant:
            result = result.filter { $0.status == .dormant }
        case .paused:
            result = result.filter { $0.status == .paused }
        case .experimental:
            result = result.filter { $0.status == .experimental }
        case .archived:
            result = result.filter { $0.status == .archived || $0.status == .abandoned }
        }

        // Apply search
        if !searchText.isEmpty {
            result = result.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText) ||
                (project.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (project.language?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply sort
        switch sortOption {
        case .recent:
            result.sort { (p1, p2) -> Bool in
                let date1 = p1.lastCommit?.date ?? .distantPast
                let date2 = p2.lastCommit?.date ?? .distantPast
                return date1 > date2
            }
        case .mostActive:
            result.sort { $0.lineCount > $1.lineCount }
        case .alphabetical:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .byLanguage:
            result.sort { ($0.language ?? "zzz") < ($1.language ?? "zzz") }
        case .byLines:
            result.sort { $0.lineCount > $1.lineCount }
        }

        return result
    }

    func updateProjects(_ projects: [Project]) {
        self.allProjects = projects
    }

    func openInFinder(_ project: Project) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path.path)
    }

    func openInEditor(_ project: Project) {
        let editor = SettingsViewModel.shared.defaultEditor
        let appName: String

        switch editor {
        case .vscode:
            appName = "Visual Studio Code"
        case .cursor:
            appName = "Cursor"
        case .xcode:
            appName = "Xcode"
        case .sublime:
            appName = "Sublime Text"
        case .finder:
            openInFinder(project)
            return
        }

        // Try to open with the editor
        let configuration = NSWorkspace.OpenConfiguration()

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier(for: editor)) {
            NSWorkspace.shared.open([project.path], withApplicationAt: appURL, configuration: configuration)
        } else {
            // Fallback to open command
            Shell.run("open -a \"\(appName)\" \"\(project.path.path)\"")
        }
    }

    private func bundleIdentifier(for editor: Editor) -> String {
        switch editor {
        case .vscode: return "com.microsoft.VSCode"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .xcode: return "com.apple.dt.Xcode"
        case .sublime: return "com.sublimetext.4"
        case .finder: return "com.apple.finder"
        }
    }

    func openGitHub(_ project: Project) {
        guard let urlString = project.githubURL,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func copyGitHubURL(_ project: Project) {
        guard let urlString = project.githubURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
    }

    func copyCloneCommand(_ project: Project) {
        guard let urlString = project.githubURL else { return }
        let cloneURL = urlString + ".git"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("git clone \(cloneURL)", forType: .string)
    }
}
