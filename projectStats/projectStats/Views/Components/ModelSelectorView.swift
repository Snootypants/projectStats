import SwiftUI

/// Full model selector view with model and thinking level pickers
struct ModelSelectorView: View {
    @Binding var selectedModel: AIModel
    @Binding var selectedThinkingLevel: ThinkingLevel
    let provider: AIProviderType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Model")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Model", selection: $selectedModel) {
                    ForEach(AIModel.models(for: provider), id: \.self) { model in
                        HStack {
                            Text(model.displayName)
                            Spacer()
                            Text(model.costLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.menu)
            }

            // Thinking level picker (only for providers that support it)
            if provider.supportsThinkingLevels {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thinking Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Thinking", selection: $selectedThinkingLevel) {
                        ForEach(ThinkingLevel.allCases, id: \.self) { level in
                            HStack {
                                Image(systemName: level.icon)
                                Text(level.displayName)
                                if level != .none {
                                    Text("(\(level.budgetTokens) tokens)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Cost estimate
            if selectedModel.inputCostPer1M > 0 {
                HStack {
                    Text("Est. cost:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedModel.costLabel)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// Compact model selector for toolbar use
struct CompactModelSelector: View {
    @Binding var selectedModel: AIModel
    @Binding var selectedThinkingLevel: ThinkingLevel
    let provider: AIProviderType
    var showThinking: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            // Model menu
            Menu {
                ForEach(AIModel.models(for: provider), id: \.self) { model in
                    Button {
                        selectedModel = model
                    } label: {
                        HStack {
                            if model == selectedModel {
                                Image(systemName: "checkmark")
                            }
                            Text(model.displayName)
                            Spacer()
                            Text(model.costLabel)
                                .font(.caption2)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text(selectedModel.shortName)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Thinking level menu (if supported)
            if showThinking && provider.supportsThinkingLevels {
                Menu {
                    ForEach(ThinkingLevel.allCases, id: \.self) { level in
                        Button {
                            selectedThinkingLevel = level
                        } label: {
                            HStack {
                                if level == selectedThinkingLevel {
                                    Image(systemName: "checkmark")
                                }
                                Image(systemName: level.icon)
                                Text(level.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedThinkingLevel.icon)
                            .font(.system(size: 10))
                        Text(selectedThinkingLevel.displayName)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(thinkingBackground)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var thinkingBackground: Color {
        switch selectedThinkingLevel {
        case .none: return Color.primary.opacity(0.05)
        case .low: return Color.blue.opacity(0.1)
        case .medium: return Color.purple.opacity(0.1)
        case .high: return Color.orange.opacity(0.1)
        }
    }
}

/// Model pill for display only (non-interactive)
struct ModelPill: View {
    let model: AIModel
    let thinkingLevel: ThinkingLevel?

    var body: some View {
        HStack(spacing: 4) {
            Text(model.shortName)
                .font(.system(size: 10, weight: .medium))

            if let thinking = thinkingLevel, thinking != .none {
                Divider()
                    .frame(height: 10)
                Image(systemName: thinking.icon)
                    .font(.system(size: 9))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.08))
        .cornerRadius(4)
    }
}

// MARK: - Extensions

extension AIModel {
    /// Short display name for compact UI
    var shortName: String {
        switch self {
        case .claudeSonnet3_5: return "Sonnet 3.5"
        case .claudeHaiku3_5: return "Haiku 3.5"
        case .claudeOpus3: return "Opus 3"
        case .claudeSonnet3: return "Sonnet 3"
        case .claudeHaiku3: return "Haiku 3"
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "4o Mini"
        case .gpt4_1: return "GPT-4.1"
        case .o3: return "o3"
        case .o4Mini: return "o4 Mini"
        case .llama3_2: return "Llama 3.2"
        case .codellama: return "CodeLlama"
        case .deepseekCoder: return "DeepSeek"
        case .qwen2_5Coder: return "Qwen"
        }
    }

    /// Cost label for display
    var costLabel: String {
        if inputCostPer1M == 0 {
            return "Free"
        }
        return "$\(String(format: "%.2f", inputCostPer1M))/$\(String(format: "%.0f", outputCostPer1M))/M"
    }
}

// MARK: - Previews

#Preview("Full Selector") {
    struct Preview: View {
        @State var model: AIModel = .claudeSonnet3_5
        @State var thinking: ThinkingLevel = .none

        var body: some View {
            ModelSelectorView(
                selectedModel: $model,
                selectedThinkingLevel: $thinking,
                provider: .claudeCode
            )
            .padding()
        }
    }
    return Preview()
}

#Preview("Compact Selector") {
    struct Preview: View {
        @State var model: AIModel = .claudeSonnet3_5
        @State var thinking: ThinkingLevel = .medium

        var body: some View {
            CompactModelSelector(
                selectedModel: $model,
                selectedThinkingLevel: $thinking,
                provider: .claudeCode
            )
            .padding()
        }
    }
    return Preview()
}
