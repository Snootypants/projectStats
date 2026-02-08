import SwiftUI
import SwiftData

struct VibeTabView: View {
    let projectPath: String

    @StateObject private var bridge: VibeTerminalBridge
    @StateObject private var conversationService = VibeConversationService.shared
    @StateObject private var summarizer = VibeSummarizerService.shared
    @Query private var allTemplates: [PromptTemplate]

    @State private var inputText: String = ""
    @State private var selectedTemplateID: UUID?
    @State private var autoScroll: Bool = true
    @State private var showLockPlanSheet: Bool = false
    @State private var planSummaryText: String = ""
    @State private var showExecutionPanel: Bool = false
    @State private var showSummaryPopover: Bool = false

    init(projectPath: String) {
        self.projectPath = projectPath
        self._bridge = StateObject(wrappedValue: VibeTerminalBridge(projectPath: URL(fileURLWithPath: projectPath)))
    }

    private var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }

    private var selectedTemplate: PromptTemplate? {
        if let id = selectedTemplateID {
            return allTemplates.first { $0.id == id }
        }
        return allTemplates.first { $0.isDefault }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()

            // Output stream
            outputStreamView

            Divider()

            // Input area + action bar
            inputArea

            // Execution monitor (collapsible)
            if showExecutionPanel || bridge.isExecuting {
                Divider()
                executionMonitor
            }
        }
        .onAppear {
            bridge.boot()
            // Auto-select default template
            if selectedTemplateID == nil, let def = allTemplates.first(where: { $0.isDefault }) {
                selectedTemplateID = def.id
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            // Project name
            Label(projectName, systemImage: "bolt.fill")
                .font(.headline)

            Spacer()

            // /plan toggle
            Button {
                bridge.sendSlashCommand("/plan")
            } label: {
                Text("/plan")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Summarize button
            Button {
                if let conv = conversationService.activeConversation {
                    summarizer.summarize(conversation: conv)
                }
            } label: {
                if summarizer.isSummarizing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Summarize", systemImage: "text.redaction")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .disabled(summarizer.isSummarizing || conversationService.activeConversation == nil)
            .popover(isPresented: $showSummaryPopover) {
                if let summary = summarizer.lastSummary {
                    ScrollView {
                        Text(summary)
                            .font(.body)
                            .padding()
                    }
                    .frame(width: 400, height: 300)
                }
            }
            .onChange(of: summarizer.lastSummary) { _, newVal in
                if newVal != nil { showSummaryPopover = true }
            }

            // Status badge
            if let status = conversationService.activeConversation?.status {
                Text(status.capitalized)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(status).opacity(0.2))
                    .foregroundStyle(statusColor(status))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Output Stream

    private var outputStreamView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(bridge.outputStream.isEmpty ? "Starting Claude in plan mode..." : bridge.outputStream)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .id("bottom")
            }
            .onChange(of: bridge.outputStream) { _, _ in
                if autoScroll {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(alignment: .topTrailing) {
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .padding(8)
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendInput()
                    }

                Button("Send") {
                    sendInput()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack(spacing: 12) {
                // Lock Plan button
                Button {
                    showLockPlanSheet = true
                } label: {
                    Label("Lock Plan", systemImage: "lock.fill")
                        .font(.caption)
                }
                .disabled(conversationService.activeConversation?.status != "planning")
                .popover(isPresented: $showLockPlanSheet) {
                    VStack(spacing: 12) {
                        Text("Plan Summary").font(.headline)
                        TextEditor(text: $planSummaryText)
                            .frame(width: 300, height: 120)
                            .font(.body)
                        HStack {
                            Button("Cancel") { showLockPlanSheet = false }
                            Spacer()
                            Button("Lock") {
                                bridge.lockPlanAndCompose(summary: planSummaryText, template: selectedTemplate)
                                showLockPlanSheet = false
                            }
                            .disabled(planSummaryText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding()
                }

                // Execute button
                Button {
                    bridge.executePrompt()
                    showExecutionPanel = true
                } label: {
                    Label("Execute", systemImage: "play.fill")
                        .font(.caption)
                }
                .disabled(conversationService.activeConversation?.status != "ready")

                Spacer()

                // Template picker
                Picker("Template", selection: $selectedTemplateID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(allTemplates) { template in
                        Text(template.name).tag(template.id as UUID?)
                    }
                }
                .frame(width: 160)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Execution Monitor

    private var executionMonitor: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Execution", systemImage: "terminal.fill")
                    .font(.caption.bold())

                if bridge.isExecuting {
                    ProgressView()
                        .controlSize(.small)
                }

                if let conv = conversationService.activeConversation, conv.status == "completed" {
                    Text("Done!")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    if let dur = conv.executionDurationSeconds {
                        Text("(\(Int(dur))s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    showExecutionPanel = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                Text(bridge.executionOutputStream.isEmpty ? "Waiting for execution output..." : bridge.executionOutputStream)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }
            .frame(height: 150)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Helpers

    private func sendInput() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        bridge.send(text)
        inputText = ""
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "planning": return .blue
        case "ready": return .orange
        case "executing": return .purple
        case "completed": return .green
        default: return .secondary
        }
    }
}
