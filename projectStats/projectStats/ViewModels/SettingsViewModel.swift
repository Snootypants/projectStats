import Foundation
import SwiftUI
import ServiceManagement

enum Editor: String, CaseIterable, Codable {
    case vscode = "Visual Studio Code"
    case xcode = "Xcode"
    case cursor = "Cursor"
    case sublime = "Sublime Text"
    case finder = "Finder"

    var icon: String {
        switch self {
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .xcode: return "hammer"
        case .cursor: return "cursorarrow"
        case .sublime: return "text.alignleft"
        case .finder: return "folder"
        }
    }
}

enum Terminal: String, CaseIterable, Codable {
    case terminal = "Terminal"
    case iterm = "iTerm"
    case warp = "Warp"
}

enum AppTheme: String, CaseIterable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()

    @AppStorage("codeDirectoryPath") private var codeDirectoryPath: String = ""
    @AppStorage("githubToken") var githubToken: String = ""
    @AppStorage("defaultEditorRaw") private var defaultEditorRaw: String = Editor.vscode.rawValue
    @AppStorage("defaultTerminalRaw") private var defaultTerminalRaw: String = Terminal.terminal.rawValue
    @AppStorage("refreshInterval") var refreshInterval: Int = 15
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }
    @AppStorage("showInDock") var showInDock: Bool = false
    @AppStorage("themeRaw") private var themeRaw: String = AppTheme.system.rawValue

    var codeDirectory: URL {
        get {
            if codeDirectoryPath.isEmpty {
                return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code")
            }
            return URL(fileURLWithPath: codeDirectoryPath)
        }
        set {
            codeDirectoryPath = newValue.path
            objectWillChange.send()
        }
    }

    var defaultEditor: Editor {
        get { Editor(rawValue: defaultEditorRaw) ?? .vscode }
        set {
            defaultEditorRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    var defaultTerminal: Terminal {
        get { Terminal(rawValue: defaultTerminalRaw) ?? .terminal }
        set {
            defaultTerminalRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        set {
            themeRaw = newValue.rawValue
            objectWillChange.send()
            applyTheme()
        }
    }

    private init() {
        applyTheme()
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    private func applyTheme() {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func selectCodeDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your code directory"

        if panel.runModal() == .OK, let url = panel.url {
            codeDirectory = url
        }
    }

    func openInTerminal(_ path: URL) {
        let terminalApp: String

        switch defaultTerminal {
        case .terminal:
            terminalApp = "Terminal"
        case .iterm:
            terminalApp = "iTerm"
        case .warp:
            terminalApp = "Warp"
        }

        Shell.run("open -a \"\(terminalApp)\" \"\(path.path)\"")
    }
}
