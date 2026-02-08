import SwiftUI
import AppKit

struct ReportGeneratorView: View {
    let project: Project
    @State private var options = ReportOptions()
    @State private var previewMarkdown: String = ""
    @State private var showPreview = false
    @State private var isGenerating = false
    @State private var exportMessage: String?

    private let generator = ReportGenerator()

    var body: some View {
        Form {
            Section {
                Picker("Report Type", selection: $options.reportType) {
                    ForEach(ReportOptions.ReportType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
            }

            Section {
                Toggle("Project overview & description", isOn: $options.includeOverview)
                Toggle("Tech stack & architecture", isOn: $options.includeTechStack)
                Toggle("Progress summary", isOn: $options.includeProgress)
                Toggle("Time invested", isOn: $options.includeTimeInvested)
                Toggle("Recent activity", isOn: $options.includeRecentActivity)
                Toggle("AI-generated status summary", isOn: $options.includeAISummary)
                Toggle("Code statistics", isOn: $options.includeCodeStats)
                Toggle("Dependency list", isOn: $options.includeDependencies)
                Toggle("Known issues / TODOs", isOn: $options.includeKnownIssues)
            } header: {
                Text("Include")
            }

            Section {
                Toggle("PDF", isOn: $options.outputPDF)
                Toggle("Markdown", isOn: $options.outputMarkdown)
                Toggle("HTML", isOn: $options.outputHTML)
                Toggle("NotebookLM-ready", isOn: $options.outputNotebook)
            } header: {
                Text("Output Format")
            }

            Section {
                HStack {
                    Button("Preview") { generatePreview() }
                    Button("Generate") { generateReport() }

                    Button {
                        exportMarkdown()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Markdown")
                        }
                    }
                    .buttonStyle(.bordered)

                    if isGenerating { ProgressView().controlSize(.small) }
                }

                if let message = exportMessage {
                    HStack {
                        Image(systemName: message.contains("Saved") ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(message.contains("Saved") ? .green : .red)
                        Text(message)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showPreview) {
            ReportPreviewView(markdown: previewMarkdown)
        }
    }

    private func generatePreview() {
        previewMarkdown = generator.generateMarkdown(for: project, options: options)
        showPreview = true
    }

    private func generateReport() {
        isGenerating = true
        Task {
            if options.includeAISummary {
                _ = await AIService.shared.send(prompt: "Write a short status summary for \(project.name).")
            }
            _ = generator.generatePDF(for: project, options: options)
            isGenerating = false

            // Collaborator achievement: generated a report
            AchievementService.shared.checkAndUnlock(.collaborator, projectPath: project.path.path)
        }
    }

    private func exportMarkdown() {
        let markdown = generator.generateMarkdown(for: project, options: options)

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(project.name.replacingOccurrences(of: " ", with: "-"))-report.md"
        panel.allowedContentTypes = [.text]
        panel.canCreateDirectories = true
        panel.title = "Export Report as Markdown"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
                exportMessage = "Saved to \(url.lastPathComponent)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    exportMessage = nil
                }
            } catch {
                exportMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ReportGeneratorView(project: Project(
        path: URL(fileURLWithPath: "/tmp/sample"),
        name: "Sample Project",
        description: "Demo project",
        githubURL: nil,
        language: "Swift",
        lineCount: 1200,
        fileCount: 42,
        promptCount: 5,
        workLogCount: 3,
        lastCommit: nil,
        lastScanned: Date(),
        githubStats: nil,
        githubStatsError: nil,
        gitMetrics: nil,
        gitRepoInfo: nil,
        jsonStatus: nil,
        techStack: [],
        languageBreakdown: [:],
        structure: nil,
        structureNotes: nil,
        sourceDirectories: [],
        excludedDirectories: [],
        firstCommitDate: nil,
        totalCommits: 0,
        branches: [],
        currentBranch: nil,
        statsGeneratedAt: nil,
        statsSource: nil
    ))
}
