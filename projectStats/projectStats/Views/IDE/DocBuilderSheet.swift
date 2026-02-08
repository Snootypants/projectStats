import SwiftUI

struct DocBuilderSheet: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    // Core docs — nothing selected by default
    @State private var buildArchitecture = false
    @State private var buildFileStructure = false
    @State private var buildModels = false
    @State private var buildServices = false
    @State private var buildViews = false
    @State private var buildViewModels = false
    @State private var buildDependencies = false
    @State private var buildDataFlow = false
    @State private var buildDatabaseSchema = false
    @State private var buildApiIntegrations = false
    @State private var buildFunctionsIndex = false
    @State private var buildKeyboardShortcuts = false
    @State private var buildSettingsReference = false
    @State private var buildNotifications = false
    @State private var buildKnownIssues = false
    @State private var buildChangelog = false
    @State private var buildTodo = false
    @State private var buildReadme = false
    @State private var buildAchievements = false
    @State private var buildQaAudit = false
    @State private var buildPrd = false

    // Sharing reports
    @State private var buildReport = false
    @State private var buildDetailedReport = false
    @State private var buildTechnicalHandoff = false

    // Collapsible section state
    @State private var coreExpanded = true
    @State private var codeRefExpanded = false
    @State private var advancedExpanded = false
    @State private var sharingExpanded = false
    @State private var customExpanded = false

    // Custom
    @State private var customDocs: [CustomDocEntry] = []
    @State private var showAddCustom = false
    @State private var newCustomTitle = ""
    @State private var newCustomDescription = ""

    // Progress
    @State private var isBuilding = false
    @State private var buildProgress: [(name: String, status: DocBuildStatus)] = []
    @State private var bridge: VibeProcessBridge?

    enum DocBuildStatus: Equatable {
        case pending, building, done, failed
    }

    struct CustomDocEntry: Identifiable {
        let id = UUID()
        var title: String
        var description: String
    }

    private var allDocEntries: [(name: String, binding: Bool)] {
        [
            ("ARCHITECTURE.md", buildArchitecture),
            ("FILE_STRUCTURE.md", buildFileStructure),
            ("README.md", buildReadme),
            ("CHANGELOG.md", buildChangelog),
            ("TODO.md", buildTodo),
            ("KNOWN_ISSUES.md", buildKnownIssues),
            ("MODELS.md", buildModels),
            ("SERVICES.md", buildServices),
            ("VIEWS.md", buildViews),
            ("VIEWMODELS.md", buildViewModels),
            ("DEPENDENCIES.md", buildDependencies),
            ("FUNCTIONS_INDEX.md", buildFunctionsIndex),
            ("DATA_FLOW.md", buildDataFlow),
            ("DATABASE_SCHEMA.md", buildDatabaseSchema),
            ("API_INTEGRATIONS.md", buildApiIntegrations),
            ("KEYBOARD_SHORTCUTS.md", buildKeyboardShortcuts),
            ("SETTINGS_REFERENCE.md", buildSettingsReference),
            ("NOTIFICATIONS.md", buildNotifications),
            ("ACHIEVEMENTS.md", buildAchievements),
            ("QA_AUDIT.md", buildQaAudit),
            ("prd.md", buildPrd),
        ]
    }

    private var selectedDocs: [String] {
        var docs: [String] = []
        for entry in allDocEntries where entry.binding {
            docs.append(entry.name)
        }
        if buildReport { docs.append("\(project.name)-report.md") }
        if buildDetailedReport { docs.append("\(project.name)-report-detailed.md") }
        if buildTechnicalHandoff { docs.append("\(project.name)-report-technicalHandoff.md") }
        for custom in customDocs {
            docs.append("\(custom.title).md")
        }
        return docs
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Doc Builder")
                        .font(.system(size: 16, weight: .bold))
                    Text("Select docs to generate. Claude reads your repo and writes each one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Quick select
                    HStack(spacing: 12) {
                        Button("Select All") { selectAll(true) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("Select None") { selectAll(false) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("Essentials") { selectEssentials() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }

                    collapsibleSection("Core Documentation", isExpanded: $coreExpanded, bindings: [$buildArchitecture, $buildFileStructure, $buildReadme, $buildChangelog, $buildTodo, $buildKnownIssues]) {
                        docToggle("ARCHITECTURE.md", "System architecture and component relationships", $buildArchitecture)
                        docToggle("FILE_STRUCTURE.md", "Complete file tree with descriptions", $buildFileStructure)
                        docToggle("README.md", "Project overview, setup, and usage", $buildReadme)
                        docToggle("CHANGELOG.md", "Version history and changes", $buildChangelog)
                        docToggle("TODO.md", "Planned work and backlog", $buildTodo)
                        docToggle("KNOWN_ISSUES.md", "Known bugs and limitations", $buildKnownIssues)
                    }

                    collapsibleSection("Code Reference", isExpanded: $codeRefExpanded, bindings: [$buildModels, $buildServices, $buildViews, $buildViewModels, $buildDependencies, $buildFunctionsIndex]) {
                        docToggle("MODELS.md", "Data model reference", $buildModels)
                        docToggle("SERVICES.md", "Service layer reference", $buildServices)
                        docToggle("VIEWS.md", "View hierarchy reference", $buildViews)
                        docToggle("VIEWMODELS.md", "ViewModel reference", $buildViewModels)
                        docToggle("DEPENDENCIES.md", "External dependencies", $buildDependencies)
                        docToggle("FUNCTIONS_INDEX.md", "Public function index", $buildFunctionsIndex)
                    }

                    collapsibleSection("Advanced", isExpanded: $advancedExpanded, bindings: [$buildDataFlow, $buildDatabaseSchema, $buildApiIntegrations, $buildKeyboardShortcuts, $buildSettingsReference, $buildNotifications, $buildAchievements, $buildQaAudit, $buildPrd]) {
                        docToggle("DATA_FLOW.md", "Data flow and state management", $buildDataFlow)
                        docToggle("DATABASE_SCHEMA.md", "Database schema reference", $buildDatabaseSchema)
                        docToggle("API_INTEGRATIONS.md", "External API integrations", $buildApiIntegrations)
                        docToggle("KEYBOARD_SHORTCUTS.md", "Keyboard shortcut reference", $buildKeyboardShortcuts)
                        docToggle("SETTINGS_REFERENCE.md", "All settings and defaults", $buildSettingsReference)
                        docToggle("NOTIFICATIONS.md", "Notification system reference", $buildNotifications)
                        docToggle("ACHIEVEMENTS.md", "Achievement system reference", $buildAchievements)
                        docToggle("QA_AUDIT.md", "Quality audit findings", $buildQaAudit)
                        docToggle("prd.md", "Product requirements document", $buildPrd)
                    }

                    collapsibleSection("Sharing & Handoff Reports", isExpanded: $sharingExpanded, bindings: [$buildReport, $buildDetailedReport, $buildTechnicalHandoff]) {
                        docToggle("Quick Status Report", "Brief project status for stakeholders", $buildReport)
                        docToggle("Detailed Report", "Comprehensive project report with stats", $buildDetailedReport)
                        docToggle("Technical Handoff", "Everything a new developer needs to know", $buildTechnicalHandoff)
                    }

                    // Custom Docs
                    docSection("Custom Documents") {
                        ForEach(customDocs) { doc in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading) {
                                    Text(doc.title)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(doc.description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { customDocs.removeAll { $0.id == doc.id } } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if showAddCustom {
                            VStack(spacing: 8) {
                                TextField("Document name (e.g. SECURITY_POLICY)", text: $newCustomTitle)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Description / what to document", text: $newCustomDescription)
                                    .textFieldStyle(.roundedBorder)
                                HStack {
                                    Button("Cancel") {
                                        showAddCustom = false
                                        newCustomTitle = ""
                                        newCustomDescription = ""
                                    }
                                    Button("Add") {
                                        guard !newCustomTitle.isEmpty else { return }
                                        customDocs.append(CustomDocEntry(
                                            title: newCustomTitle.uppercased().replacingOccurrences(of: " ", with: "_"),
                                            description: newCustomDescription
                                        ))
                                        showAddCustom = false
                                        newCustomTitle = ""
                                        newCustomDescription = ""
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        } else {
                            Button {
                                showAddCustom = true
                            } label: {
                                Label("Add Custom Document", systemImage: "plus.circle")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Build progress
                    if isBuilding || !buildProgress.isEmpty {
                        docSection("Build Progress") {
                            ForEach(Array(buildProgress.enumerated()), id: \.offset) { _, entry in
                                HStack(spacing: 8) {
                                    switch entry.status {
                                    case .pending:
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 16, height: 16)
                                    case .building:
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 16, height: 16)
                                    case .done:
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .frame(width: 16, height: 16)
                                    case .failed:
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(entry.name)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                Text("\(selectedDocs.count) docs selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isBuilding {
                    Button("Stop") {
                        stopBuild()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                } else {
                    Button {
                        startBuild()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hammer.fill")
                            Text("Build Docs")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(selectedDocs.isEmpty)
                }
            }
            .padding(16)
        }
        .frame(width: 520, height: 620)
    }

    // MARK: - Helper Views

    private func docSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func collapsibleSection<Content: View>(_ title: String, isExpanded: Binding<Bool>, bindings: [Binding<Bool>], @ViewBuilder content: () -> Content) -> some View {
        let allOn = bindings.allSatisfy { $0.wrappedValue }
        let anyOn = bindings.contains { $0.wrappedValue }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Disclosure triangle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)

                // Group checkbox
                Button {
                    let newValue = !allOn
                    for binding in bindings {
                        binding.wrappedValue = newValue
                    }
                } label: {
                    Image(systemName: allOn ? "checkmark.square.fill" : (anyOn ? "minus.square.fill" : "square"))
                        .foregroundStyle(allOn || anyOn ? .blue : .secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                let count = bindings.filter(\.wrappedValue).count
                if count > 0 {
                    Text("\(count)/\(bindings.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding(.leading, 22)
            }
        }
    }

    private func docToggle(_ name: String, _ description: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
    }

    // MARK: - Selection Helpers

    private func selectAll(_ value: Bool) {
        buildArchitecture = value; buildFileStructure = value; buildModels = value
        buildServices = value; buildViews = value; buildViewModels = value
        buildDependencies = value; buildDataFlow = value; buildDatabaseSchema = value
        buildApiIntegrations = value; buildFunctionsIndex = value; buildKeyboardShortcuts = value
        buildSettingsReference = value; buildNotifications = value; buildKnownIssues = value
        buildChangelog = value; buildTodo = value; buildReadme = value
        buildAchievements = value; buildQaAudit = value; buildPrd = value
        buildReport = value; buildDetailedReport = value; buildTechnicalHandoff = value
    }

    private func selectEssentials() {
        selectAll(false)
        buildArchitecture = true; buildFileStructure = true; buildReadme = true
        buildChangelog = true; buildTodo = true; buildKnownIssues = true
        buildModels = true; buildServices = true; buildViews = true
        buildViewModels = true; buildDependencies = true
    }

    // MARK: - Build Logic

    private func startBuild() {
        let docs = selectedDocs
        guard !docs.isEmpty else { return }

        isBuilding = true
        buildProgress = docs.map { ($0, DocBuildStatus.pending) }

        let projectDir = project.path.path
        let useSwarm = AgentTeamsService.isSwarmEnabled(for: projectDir)

        Task {
            let vpb = VibeProcessBridge()

            var outputBuffer = ""
            vpb.start(directory: projectDir) { text in
                outputBuffer += text
            }
            bridge = vpb

            // Give shell time to initialize
            try? await Task.sleep(nanoseconds: 500_000_000)

            if useSwarm {
                // Swarm mode: single prompt telling Claude to use Task tool for parallel workers
                let docList = docs.joined(separator: ", ")
                let prompt = """
                Read the entire codebase. Generate these documentation files in the docs/ directory: \(docList). \
                Use the Task tool to spawn parallel workers, one per document. Each doc must be concise, accurate, \
                and based on actual code. Do not hallucinate. For reports, save to docs/reports/ subdirectory.
                """
                markAllBuilding()
                vpb.send("claude \"\(prompt.replacingOccurrences(of: "\"", with: "\\\""))\"")
                // Monitor for completion
                await monitorCompletion(docs: docs, buffer: &outputBuffer)
            } else {
                // Sequential mode: one doc at a time
                for (index, doc) in docs.enumerated() {
                    guard isBuilding else { break }
                    updateStatus(index: index, status: .building)

                    let subdir = isReport(doc) ? "docs/reports" : "docs"
                    let prompt = buildPrompt(for: doc, subdir: subdir)

                    outputBuffer = ""
                    vpb.send("claude \"\(prompt.replacingOccurrences(of: "\"", with: "\\\""))\"")

                    // Wait for Claude to finish (look for shell prompt return)
                    await waitForCompletion(buffer: &outputBuffer)
                    updateStatus(index: index, status: .done)
                }
            }

            vpb.stop()
            bridge = nil
            isBuilding = false
        }
    }

    private func stopBuild() {
        isBuilding = false
        bridge?.stop()
        bridge = nil
    }

    private func buildPrompt(for doc: String, subdir: String) -> String {
        // Check if it's a custom doc
        if let custom = customDocs.first(where: { "\($0.title).md" == doc }) {
            return "Read the codebase. Generate \(subdir)/\(doc) documenting: \(custom.description). Be concise and accurate. Use actual code, do not hallucinate."
        }

        return "Read the codebase. Generate \(subdir)/\(doc) with accurate, concise documentation based on the actual code. Do not hallucinate."
    }

    private func isReport(_ doc: String) -> Bool {
        doc.contains("-report")
    }

    private func markAllBuilding() {
        for i in buildProgress.indices {
            buildProgress[i].status = .building
        }
    }

    private func updateStatus(index: Int, status: DocBuildStatus) {
        guard index < buildProgress.count else { return }
        buildProgress[index].status = status
    }

    private func waitForCompletion(buffer: inout String) async {
        // Poll for shell prompt return (indicates Claude finished)
        let start = Date()
        let timeout: TimeInterval = 300 // 5 min max per doc
        while isBuilding {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Date().timeIntervalSince(start) > timeout { break }
            // Check if output contains a shell prompt ($ or %) indicating Claude is done
            if buffer.hasSuffix("$ ") || buffer.hasSuffix("% ") ||
               buffer.contains("\n$ ") || buffer.contains("\n% ") {
                // Give a brief pause for any trailing output
                try? await Task.sleep(nanoseconds: 500_000_000)
                break
            }
        }
    }

    private func monitorCompletion(docs: [String], buffer: inout String) async {
        let start = Date()
        let timeout: TimeInterval = 600 // 10 min for swarm
        while isBuilding {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Date().timeIntervalSince(start) > timeout { break }

            // Check each doc for file write confirmation in output
            for (index, doc) in docs.enumerated() {
                if buildProgress[index].status == .building {
                    if buffer.contains(doc) && (buffer.contains("Created") || buffer.contains("wrote") || buffer.contains("generated")) {
                        updateStatus(index: index, status: .done)
                    }
                }
            }

            // Check if all done
            if buildProgress.allSatisfy({ $0.status == .done }) { break }

            // Check for shell prompt (all work complete)
            if buffer.hasSuffix("$ ") || buffer.hasSuffix("% ") {
                // Mark remaining as done
                for i in buildProgress.indices where buildProgress[i].status == .building {
                    updateStatus(index: i, status: .done)
                }
                break
            }
        }
    }
}
