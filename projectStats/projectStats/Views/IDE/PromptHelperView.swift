import SwiftData
import SwiftUI

// MARK: - Prompt Composition Logic (testable)

enum PromptHelperComposer {
    /// Compose a final prompt from user text and optional template content.
    /// If template contains `{PROMPT}`, replace it with user text.
    /// If template has no placeholder, prepend template + newlines + user text.
    /// If no template, return user text as-is.
    /// Empty user text always returns empty string.
    static func compose(userText: String, templateContent: String?) -> String {
        guard !userText.isEmpty else { return "" }
        guard let template = templateContent, !template.isEmpty else { return userText }

        if template.contains("{PROMPT}") {
            return template.replacingOccurrences(of: "{PROMPT}", with: userText)
        } else {
            return "\(template)\n\n\(userText)"
        }
    }
}

// MARK: - Prompt Helper View

struct PromptHelperView: View {
    let projectPath: URL

    @Query private var allTemplates: [PromptTemplate]
    @State private var promptText: String = ""
    @State private var selectedTemplateID: UUID?
    @State private var showSentConfirmation = false

    private var templates: [PromptTemplate] {
        allTemplates.sorted { $0.name < $1.name }
    }

    private var selectedTemplate: PromptTemplate? {
        guard let id = selectedTemplateID else { return nil }
        return templates.first { $0.id == id }
    }

    /// The effective template: explicitly selected, or fall back to default (mandatory chrome)
    private var effectiveTemplate: PromptTemplate? {
        if let selected = selectedTemplate { return selected }
        // Mandatory chrome: auto-apply default template when none explicitly selected
        return templates.first { $0.isDefault }
    }

    private var composedPrompt: String {
        PromptHelperComposer.compose(
            userText: promptText,
            templateContent: effectiveTemplate?.content
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            // Compose area
            TextEditor(text: $promptText)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)

            Divider()

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.secondary)

            Text("Prompt Helper")
                .font(.system(size: 12, weight: .semibold))

            Spacer()

            // Template picker
            Picker("Template", selection: $selectedTemplateID) {
                Text("No Template").tag(UUID?.none)
                ForEach(templates) { template in
                    Text(template.name).tag(Optional(template.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            if let template = effectiveTemplate {
                let isAuto = selectedTemplate == nil && template.isDefault
                Label(
                    isAuto ? "\(template.name) (auto)" : template.name,
                    systemImage: isAuto ? "sparkles" : "doc.text"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text("\(composedPrompt.count) chars")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            if showSentConfirmation {
                Label("Sent!", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            }

            Button {
                sendToClaudeCode()
            } label: {
                Label("Send to Claude", systemImage: "paperplane.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderedProminent)
            .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Actions

    private func sendToClaudeCode() {
        let finalPrompt = composedPrompt
        guard !finalPrompt.isEmpty else { return }

        let terminalVM = TerminalTabsViewModel.shared
        terminalVM.setProject(projectPath)

        // Generate the claude command with the prompt embedded
        let command = ThinkingLevelService.shared.generatePromptCommand(
            prompt: finalPrompt,
            model: SettingsViewModel.shared.terminalClaudeModel,
            thinkingLevel: SettingsViewModel.shared.defaultThinkingLevel
        )

        // Create a new Claude terminal tab with the command
        let tab = TerminalTabItem(
            kind: .claude,
            title: "Prompt Helper",
            aiModel: SettingsViewModel.shared.terminalClaudeModel,
            thinkingLevel: SettingsViewModel.shared.defaultThinkingLevel
        )
        tab.devCommand = command
        terminalVM.tabs.append(tab)
        terminalVM.activeTabID = tab.id
        tab.enqueueCommand(command)

        // Record template usage (effective template, including auto-applied default)
        if let template = effectiveTemplate {
            template.recordPromptUse()
        }

        // Save to database
        Task { @MainActor in
            do {
                let context = AppModelContainer.shared.mainContext
                let saved = SavedPrompt(
                    text: finalPrompt,
                    projectPath: projectPath.path,
                    wasExecuted: true
                )
                context.insert(saved)
                try context.save()
            } catch {
                print("[PromptHelper] Failed to save prompt: \(error)")
            }
        }

        // Show confirmation
        showSentConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSentConfirmation = false
        }

        // Clear for next prompt
        promptText = ""
    }
}
