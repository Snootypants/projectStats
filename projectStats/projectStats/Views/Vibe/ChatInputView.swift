import SwiftUI

struct ChatInputView: View {
    @ObservedObject var viewModel: VibeChatViewModel
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Ask Claude Code...", text: $viewModel.currentInput, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .onSubmit { viewModel.sendMessage() }

            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        canSend ? Color.accentColor : .secondary
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: .command)
            .padding(.trailing, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 6)
    }

    private var canSend: Bool {
        isEnabled && !viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
