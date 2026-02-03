import SwiftUI

struct DevServerToolbar: View {
    @ObservedObject var tab: TerminalTabItem
    @State private var showCustomCommandSheet = false
    @State private var customCommand = ""

    var body: some View {
        HStack(spacing: 8) {
            Button("npm run dev") { tab.sendCommand("npm run dev") }
            Button("npm start") { tab.sendCommand("npm start") }
            Button("yarn dev") { tab.sendCommand("yarn dev") }
            Button("npx prisma studio") { tab.sendCommand("npx prisma studio") }
            Button("python manage.py runserver") { tab.sendCommand("python manage.py runserver") }

            Button("Custom") {
                showCustomCommandSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
        .sheet(isPresented: $showCustomCommandSheet) {
            VStack(spacing: 16) {
                Text("Custom Command")
                    .font(.headline)

                TextField("Command", text: $customCommand)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        showCustomCommandSheet = false
                        customCommand = ""
                    }
                    Button("Run") {
                        let trimmed = customCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            tab.sendCommand(trimmed)
                        }
                        showCustomCommandSheet = false
                        customCommand = ""
                    }
                }
            }
            .padding(20)
            .frame(width: 360)
        }
    }
}
