import SwiftData
import SwiftUI

struct DiffManagerView: View {
    let projectPath: URL

    @Query private var allSavedDiffs: [SavedDiff]
    @State private var selectedDiffID: UUID?
    @State private var showCopiedAlert: Bool = false

    private var savedDiffs: [SavedDiff] {
        allSavedDiffs
            .filter { $0.projectPath == projectPath.path }
            .sorted {
                // Sort by source file number if exists, otherwise by date
                if let sf1 = $0.sourceFile, let sf2 = $1.sourceFile {
                    return extractNumber(from: sf1) < extractNumber(from: sf2)
                }
                // If only one has sourceFile, prioritize it
                if $0.sourceFile != nil && $1.sourceFile == nil { return true }
                if $0.sourceFile == nil && $1.sourceFile != nil { return false }
                // Both have no sourceFile, sort by date
                return $0.createdAt < $1.createdAt
            }
    }

    private var selectedDiff: SavedDiff? {
        guard let id = selectedDiffID else { return nil }
        return savedDiffs.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if savedDiffs.isEmpty {
                emptyState
            } else {
                // Horizontal diff tabs
                diffTabBar

                Divider()

                // Full diff content
                diffContent

                Divider()

                // Action bar with stats
                actionBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Select first diff by default
            if selectedDiffID == nil, let first = savedDiffs.first {
                selectedDiffID = first.id
            }
        }
    }

    // MARK: - Diff Tab Bar

    private var diffTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(savedDiffs) { diff in
                    diffTab(for: diff)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.primary.opacity(0.03))
    }

    private func diffTab(for diff: SavedDiff) -> some View {
        let isSelected = selectedDiffID == diff.id
        let label = diffLabel(for: diff)

        return Button {
            selectedDiffID = diff.id
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))

                // Mini stats
                if diff.linesAdded > 0 || diff.linesRemoved > 0 {
                    HStack(spacing: 2) {
                        if diff.linesAdded > 0 {
                            Text("+\(diff.linesAdded)")
                                .font(.system(size: 9))
                                .foregroundStyle(.green)
                        }
                        if diff.linesRemoved > 0 {
                            Text("-\(diff.linesRemoved)")
                                .font(.system(size: 9))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func diffLabel(for diff: SavedDiff) -> String {
        if let commitHash = diff.commitHash {
            return String(commitHash.prefix(7))
        } else if let sourceFile = diff.sourceFile {
            return sourceFile.replacingOccurrences(of: ".md", with: "")
        } else {
            if let index = savedDiffs.firstIndex(where: { $0.id == diff.id }) {
                return "D\(index + 1)"
            }
            return "?"
        }
    }

    // MARK: - Diff Content

    private var diffContent: some View {
        ScrollView {
            if let diff = selectedDiff {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(diff.diffText.components(separatedBy: "\n"), id: \.self) { line in
                        diffLine(line)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            } else {
                Text("Select a diff")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func diffLine(_ line: String) -> some View {
        let colors = diffLineColors(line)
        return Text(line.isEmpty ? " " : line)
            .foregroundStyle(colors.fg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1)
            .padding(.horizontal, 4)
            .background(colors.bg)
            .textSelection(.enabled)
    }

    private func diffLineColors(_ line: String) -> (bg: Color, fg: Color) {
        if line.hasPrefix("+++") || line.hasPrefix("---") {
            return (Color.blue.opacity(0.1), .primary)
        } else if line.hasPrefix("+") {
            return (Color.green.opacity(0.15), .primary)
        } else if line.hasPrefix("-") {
            return (Color.red.opacity(0.15), .primary)
        } else if line.hasPrefix("@@") {
            return (Color.purple.opacity(0.1), .purple)
        } else if line.hasPrefix("diff --git") {
            return (Color.orange.opacity(0.1), .orange)
        } else {
            return (.clear, .primary)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            if let diff = selectedDiff {
                HStack(spacing: 12) {
                    if diff.filesChanged > 0 {
                        Label("\(diff.filesChanged) files", systemImage: "doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Text("+\(diff.linesAdded)")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("-\(diff.linesRemoved)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()

            Button {
                copySelectedDiff()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                    Text(showCopiedAlert ? "Copied!" : "Copy Diff")
                }
                .font(.system(size: 12))
            }
            .buttonStyle(.borderedProminent)
            .tint(showCopiedAlert ? .green : .accentColor)
            .disabled(selectedDiff == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No diffs yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Diffs will appear here when code changes are captured")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func copySelectedDiff() {
        guard let diff = selectedDiff else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diff.diffText, forType: .string)

        showCopiedAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedAlert = false
        }
    }

    // MARK: - Helpers

    private func extractNumber(from filename: String) -> Int {
        let name = filename.replacingOccurrences(of: ".md", with: "")
        var numStr = ""
        for char in name {
            if char.isNumber {
                numStr.append(char)
            } else {
                break
            }
        }
        return Int(numStr) ?? 999
    }
}
