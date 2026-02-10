import Foundation

/// Represents the content state of a single tab
enum TabContent: Equatable {
    case home
    case projectPicker
    case projectWorkspace(projectPath: String)

    static func == (lhs: TabContent, rhs: TabContent) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home): return true
        case (.projectPicker, .projectPicker): return true
        case (.projectWorkspace(let a), .projectWorkspace(let b)): return a == b
        default: return false
        }
    }
}

/// A single tab in the app
struct AppTab: Identifiable, Equatable {
    let id: UUID
    var content: TabContent
    var isPinned: Bool

    /// Display title for the tab
    var title: String {
        switch content {
        case .home: return "Home"
        case .projectPicker: return "Projects"
        case .projectWorkspace(let path):
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }

    /// SF Symbol for the tab
    var icon: String {
        switch content {
        case .home: return "house.fill"
        case .projectPicker: return "square.grid.2x2"
        case .projectWorkspace: return "folder.fill"
        }
    }

    /// Whether this tab can be closed
    var isCloseable: Bool { !isPinned }

    static func homeTab() -> AppTab {
        AppTab(id: UUID(), content: .home, isPinned: true)
    }

    static func newTab() -> AppTab {
        AppTab(id: UUID(), content: .projectPicker, isPinned: false)
    }

    static func == (lhs: AppTab, rhs: AppTab) -> Bool {
        lhs.id == rhs.id
    }
}
