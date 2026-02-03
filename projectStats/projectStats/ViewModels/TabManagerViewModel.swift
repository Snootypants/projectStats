import Foundation
import SwiftUI

@MainActor
class TabManagerViewModel: ObservableObject {
    static let shared = TabManagerViewModel()

    @Published var tabs: [AppTab]
    @Published var activeTabID: UUID

    /// Workspace state preserved when a project tab navigates "back" to picker
    private var parkedWorkspaces: [String: ParkedWorkspaceState] = [:]
    @Published private(set) var favoriteTabProjects: Set<String> = [] {
        didSet { saveFavoriteTabs() }
    }
    private let favoriteTabsKey = "favoriteTabProjects"

    private init() {
        let homeTab = AppTab.homeTab()
        self.tabs = [homeTab]
        self.activeTabID = homeTab.id
        loadFavoriteTabs()
    }

    var activeTab: AppTab? {
        tabs.first { $0.id == activeTabID }
    }

    var activeTabIndex: Int? {
        tabs.firstIndex { $0.id == activeTabID }
    }

    // MARK: - Tab Actions

    /// Open a new Project Picker tab and switch to it
    func newTab() {
        let tab = AppTab.newTab()
        tabs.append(tab)
        activeTabID = tab.id
    }

    /// Close a tab by ID (cannot close pinned tabs)
    func closeTab(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }), tab.isCloseable else { return }

        // If closing the active tab, switch to adjacent tab
        if id == activeTabID {
            if let index = tabs.firstIndex(where: { $0.id == id }) {
                let nextIndex = index > 0 ? index - 1 : min(index + 1, tabs.count - 1)
                if nextIndex < tabs.count {
                    activeTabID = tabs[nextIndex].id
                }
            }
        }

        tabs.removeAll { $0.id == id }
    }

    func closeOtherTabs(keeping id: UUID) {
        tabs = tabs.filter { $0.id == id || !$0.isCloseable }
        activeTabID = id
    }

    /// Switch to a specific tab
    func selectTab(_ id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            activeTabID = id
        }
    }

    /// Switch to tab at index (for Cmd+1, Cmd+2, etc.)
    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count else { return }
        activeTabID = tabs[index].id
    }

    func isFavorite(_ tab: AppTab) -> Bool {
        guard case .projectWorkspace(let path) = tab.content else { return false }
        return favoriteTabProjects.contains(path)
    }

    func toggleFavorite(_ tab: AppTab) {
        guard case .projectWorkspace(let path) = tab.content else { return }
        if favoriteTabProjects.contains(path) {
            favoriteTabProjects.remove(path)
        } else {
            favoriteTabProjects.insert(path)
        }
    }

    /// Navigate to next tab
    func nextTab() {
        guard let currentIndex = activeTabIndex else { return }
        let nextIndex = (currentIndex + 1) % tabs.count
        activeTabID = tabs[nextIndex].id
    }

    /// Navigate to previous tab
    func previousTab() {
        guard let currentIndex = activeTabIndex else { return }
        let prevIndex = currentIndex > 0 ? currentIndex - 1 : tabs.count - 1
        activeTabID = tabs[prevIndex].id
    }

    /// Move a tab from one position to another
    func moveTab(from sourceId: UUID, to destinationId: UUID) {
        guard let sourceIndex = tabs.firstIndex(where: { $0.id == sourceId }),
              let destIndex = tabs.firstIndex(where: { $0.id == destinationId }),
              sourceIndex != destIndex else { return }

        let tab = tabs.remove(at: sourceIndex)
        let newIndex = sourceIndex < destIndex ? destIndex : destIndex
        tabs.insert(tab, at: newIndex)
    }

    /// Open a project in the current tab (transforms picker → workspace)
    /// If the project is already open in another tab, switch to that tab instead
    func openProject(path: String) {
        // Check if this project is already open in any tab
        if let existingTab = tabs.first(where: {
            if case .projectWorkspace(let p) = $0.content { return p == path }
            return false
        }) {
            activeTabID = existingTab.id
            return
        }

        // Transform the current tab into a workspace
        if let index = tabs.firstIndex(where: { $0.id == activeTabID }) {
            tabs[index].content = .projectWorkspace(projectPath: path)
        }
    }

    /// Navigate back from workspace to project picker (park the workspace)
    func navigateBack() {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }),
              case .projectWorkspace(let path) = tabs[index].content else { return }

        // Park workspace state for potential restoration
        parkedWorkspaces[path] = ParkedWorkspaceState(projectPath: path)

        // Return tab to picker
        tabs[index].content = .projectPicker
    }

    // MARK: - State Persistence

    /// Save tab state to UserDefaults (call on app quit or periodically)
    func saveState() {
        let tabData: [[String: Any]] = tabs.map { tab in
            switch tab.content {
            case .home: return ["type": "home"]
            case .projectPicker: return ["type": "picker"]
            case .projectWorkspace(let path): return ["type": "workspace", "path": path]
            }
        }

        if let data = try? JSONSerialization.data(withJSONObject: tabData) {
            UserDefaults.standard.set(data, forKey: "openTabs")
        }

        if let index = activeTabIndex {
            UserDefaults.standard.set(index, forKey: "activeTabIndex")
        }
    }

    /// Restore tab state from UserDefaults (call on app launch)
    func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: "openTabs"),
              let tabData = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }

        var restoredTabs: [AppTab] = []

        for entry in tabData {
            guard let type = entry["type"] as? String else { continue }
            switch type {
            case "home":
                restoredTabs.append(.homeTab())
            case "picker":
                restoredTabs.append(.newTab())
            case "workspace":
                if let path = entry["path"] as? String {
                    restoredTabs.append(AppTab(
                        id: UUID(),
                        content: .projectWorkspace(projectPath: path),
                        isPinned: false
                    ))
                }
            default:
                break
            }
        }

        // Ensure Home tab exists
        if !restoredTabs.contains(where: { $0.content == .home }) {
            restoredTabs.insert(.homeTab(), at: 0)
        }

        tabs = restoredTabs

        let savedIndex = UserDefaults.standard.integer(forKey: "activeTabIndex")
        if savedIndex >= 0, savedIndex < tabs.count {
            activeTabID = tabs[savedIndex].id
        } else {
            activeTabID = tabs[0].id
        }
    }

    private func loadFavoriteTabs() {
        guard let data = UserDefaults.standard.data(forKey: favoriteTabsKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        favoriteTabProjects = Set(decoded)
    }

    private func saveFavoriteTabs() {
        let list = Array(favoriteTabProjects)
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: favoriteTabsKey)
        }
    }
}

/// Minimal state saved when a workspace is "parked" (navigated back)
struct ParkedWorkspaceState {
    let projectPath: String
    // Future: expandedFolders, openFiles, scrollPosition, terminalState, etc.
}
