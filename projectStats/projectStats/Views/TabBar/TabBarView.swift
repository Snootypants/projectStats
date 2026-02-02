import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var tabManager: TabManagerViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Tab strip (scrollable if many tabs)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabManager.tabs) { tab in
                        TabBarItem(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabID,
                            onSelect: { tabManager.selectTab(tab.id) },
                            onClose: { tabManager.closeTab(tab.id) }
                        )
                    }
                }
            }

            // New tab button
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
            .help("New Tab (Cmd+T)")
            .padding(.horizontal, 4)

            Spacer()

            // Global actions (right side)
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
}

struct TabBarItem: View {
    let tab: AppTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            // Tab icon
            Image(systemName: tab.icon)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? .primary : .secondary)

            // Tab title
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isActive ? .primary : .secondary)

            // Close button (not on pinned tabs)
            if tab.isCloseable {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isActive ? 1 : 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? Color.primary.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isActive ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}
