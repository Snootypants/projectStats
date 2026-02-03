import SwiftUI

struct Command: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let shortcut: String?
    let action: () -> Void
}

struct CommandPaletteView: View {
    @State private var query = ""
    @FocusState private var isFocused: Bool

    let commands: [Command]

    var filteredCommands: [Command] {
        if query.isEmpty { return commands }
        return commands.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Search commands...", text: $query)
                .textFieldStyle(.plain)
                .font(.title2)
                .focused($isFocused)
                .padding(.bottom, 8)

            List(filteredCommands) { command in
                HStack {
                    Image(systemName: command.icon)
                    Text(command.name)
                    Spacer()
                    if let shortcut = command.shortcut {
                        Text(shortcut)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { command.action() }
            }
        }
        .padding(20)
        .frame(width: 520, height: 420)
        .onAppear { isFocused = true }
    }
}

#Preview {
    CommandPaletteView(commands: [
        Command(name: "Open Settings", icon: "gear", shortcut: "⌘,", action: {}),
        Command(name: "Generate Report", icon: "doc.text", shortcut: "⌘⇧R", action: {})
    ])
}
