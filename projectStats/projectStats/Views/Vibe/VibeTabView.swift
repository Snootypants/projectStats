import SwiftUI

struct VibeTabView: View {
    let projectPath: String

    @StateObject private var viewModel: VibeChatViewModel

    init(projectPath: String) {
        self.projectPath = projectPath
        self._viewModel = StateObject(wrappedValue: VibeChatViewModelStore.shared.viewModel(for: projectPath))
    }

    private var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main chat area (75%)
            VStack(spacing: 0) {
                chatArea
                ChatInputView(viewModel: viewModel, isEnabled: viewModel.sessionState == .running || viewModel.sessionState == .thinking)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Sidebar (25%)
            if viewModel.sessionState != .idle {
                SessionStatsView(viewModel: viewModel)
                    .frame(width: 200)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }

    // MARK: - Chat Area

    @ViewBuilder
    private var chatArea: some View {
        if viewModel.sessionState == .idle {
            emptyState
        } else {
            chatList
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bolt.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("VIBE")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            Text(projectName)
                .font(.headline)
                .foregroundStyle(.secondary)

            // Permission mode selector
            VStack(spacing: 8) {
                Picker("Mode", selection: Binding(
                    get: { viewModel.selectedPermissionMode },
                    set: { viewModel.selectedPermissionMode = $0 }
                )) {
                    Text("Sans Flavor").tag(PermissionMode.sansFlavor)
                    Text("Flavor").tag(PermissionMode.flavor)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                Text(viewModel.selectedPermissionMode == .flavor
                     ? "Autonomous, no interruptions"
                     : "Review each action")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if viewModel.claudeFound {
                Button(action: { viewModel.startSession() }) {
                    Label("Start Claude Code", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Claude Code not found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Install with: npm install -g @anthropic-ai/claude-code")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Chat List

    private var chatList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.messages) { message in
                        messageView(for: message)
                    }

                    // Thinking indicator
                    if viewModel.isThinking {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.leading, 20)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Waiting for approval indicator
                    if viewModel.sessionState == .waitingForApproval {
                        HStack(spacing: 6) {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Waiting for approval")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 8)
                    }

                    Color.clear.frame(height: 1).id("chatBottom")
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("chatBottom", anchor: .bottom)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private func messageView(for message: VibeChatMessage) -> some View {
        switch message.content {
        case .text:
            ChatBubbleView(message: message)
        case .toolCall:
            ToolCallCardView(message: message) {
                viewModel.toggleToolExpansion(messageId: message.id)
            }
        case .permissionRequest:
            PermissionCardView(
                message: message,
                onAllow: { viewModel.approvePermission(messageId: message.id) },
                onDeny: { viewModel.denyPermission(messageId: message.id) },
                onAllowAll: { viewModel.enableAutoApprove() }
            )
        case .error:
            ChatBubbleView(message: message)
        case .sessionStats:
            ChatBubbleView(message: message)
        }
    }
}
