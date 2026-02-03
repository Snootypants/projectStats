import AppKit
import SwiftUI

struct RunningServersPopover: View {
    let servers: [TerminalTabItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Running Servers")
                .font(.system(size: 12, weight: .semibold))

            if servers.isEmpty {
                Text("No servers running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(servers) { server in
                    Button {
                        copyURL(for: server)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.devCommand ?? server.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                Text(server.port == nil ? "waiting for port" : "localhost:\(server.port!)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .onTapGesture {
                        guard NSApp.currentEvent?.modifierFlags.contains(.control) == true else { return }
                        openURL(for: server)
                    }
                    .contextMenu {
                        Button("Open in Browser") {
                            openURL(for: server)
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    private func copyURL(for server: TerminalTabItem) {
        guard let port = server.port else { return }
        let url = "http://localhost:\(port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    private func openURL(for server: TerminalTabItem) {
        guard let port = server.port else { return }
        let url = URL(string: "http://localhost:\(port)")!
        NSWorkspace.shared.open(url)
    }
}
