import SwiftUI
import SwiftData

struct ScratchPadView: View {
    let projectPath: String
    @Environment(\.modelContext) private var modelContext

    @State private var content: String = ""
    @State private var note: ProjectNote?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button("New Note") { newNote() }
                Button("Save") { saveNote() }
            }

            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)

            if let updated = note?.updatedAt {
                Text("Last edited: \(updated.relativeString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear { loadNote() }
    }

    private func loadNote() {
        let descriptor = FetchDescriptor<ProjectNote>(predicate: #Predicate { $0.projectPath == projectPath })
        if let existing = try? modelContext.fetch(descriptor).first {
            note = existing
            content = existing.content
        }
    }

    private func saveNote() {
        if let note {
            note.content = content
            note.updatedAt = Date()
        } else {
            let newNote = ProjectNote(projectPath: projectPath, content: content)
            modelContext.insert(newNote)
            note = newNote
        }
        try? modelContext.save()
    }

    private func newNote() {
        content = ""
        note = nil
    }
}

#Preview {
    ScratchPadView(projectPath: "/tmp/sample")
}
