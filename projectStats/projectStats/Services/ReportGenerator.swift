import Foundation
import PDFKit
import AppKit

struct ReportOptions: Codable {
    enum ReportType: String, Codable, CaseIterable {
        case quick
        case detailed
        case handoff

        var title: String {
            switch self {
            case .quick: return "Quick Status"
            case .detailed: return "Detailed Report"
            case .handoff: return "Technical Handoff"
            }
        }
    }

    var reportType: ReportType = .quick
    var includeOverview: Bool = true
    var includeTechStack: Bool = true
    var includeProgress: Bool = true
    var includeTimeInvested: Bool = true
    var includeRecentActivity: Bool = true
    var includeAISummary: Bool = true
    var includeCodeStats: Bool = false
    var includeDependencies: Bool = false
    var includeKnownIssues: Bool = false
    var outputPDF: Bool = true
    var outputMarkdown: Bool = true
    var outputHTML: Bool = false
    var outputNotebook: Bool = false
}

final class ReportGenerator {
    func generatePDF(for project: Project, options: ReportOptions, summary: String? = nil) -> Data {
        let document = PDFDocument()
        let titlePage = makePage(title: project.name, subtitle: options.reportType.title, body: summary ?? "")
        document.insert(titlePage, at: 0)
        return document.dataRepresentation() ?? Data()
    }

    func generateMarkdown(for project: Project, options: ReportOptions, summary: String? = nil) -> String {
        var lines: [String] = []
        lines.append("# Project Status: \(project.name)")
        lines.append("")
        if options.includeOverview {
            lines.append("## Overview")
            lines.append(project.description ?? "No description provided.")
            lines.append("")
        }
        if let summary, options.includeAISummary {
            lines.append("## AI Summary")
            lines.append(summary)
            lines.append("")
        }
        if options.includeProgress {
            lines.append("## Progress")
            lines.append("Commits: \(project.totalCommits ?? 0)")
            lines.append("Last Commit: \(project.lastCommit?.message ?? "")")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func generateNotebookLM(for project: Project, options: ReportOptions, summary: String? = nil) -> String {
        var lines: [String] = []
        lines.append("# Project Status: \(project.name)")
        lines.append("")
        lines.append("## Overview")
        lines.append(project.description ?? "No description available.")
        lines.append("")
        if let summary {
            lines.append("## Recent Progress")
            lines.append(summary)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func makePage(title: String, subtitle: String, body: String) -> PDFPage {
        let size = CGSize(width: 612, height: 792)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.white.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: NSColor.labelColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.textColor
        ]

        title.draw(at: CGPoint(x: 48, y: size.height - 96), withAttributes: titleAttributes)
        subtitle.draw(at: CGPoint(x: 48, y: size.height - 130), withAttributes: subtitleAttributes)

        let bodyRect = CGRect(x: 48, y: 48, width: size.width - 96, height: size.height - 200)
        let bodyString = NSAttributedString(string: body, attributes: bodyAttributes)
        bodyString.draw(in: bodyRect)

        image.unlockFocus()
        return PDFPage(image: image)!
    }
}
