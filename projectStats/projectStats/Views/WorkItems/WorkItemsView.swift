import SwiftUI
import SwiftData

struct WorkItemsView: View {
    let projectPath: String?
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [WorkItem]

    @State private var showAddSheet = false
    @State private var filterStatus: String? = nil
    @State private var filterType: String? = nil

    init(projectPath: String? = nil) {
        self.projectPath = projectPath
        if let path = projectPath {
            _allItems = Query(filter: #Predicate<WorkItem> { $0.projectPath == path })
        } else {
            _allItems = Query()
        }
    }

    private var filteredItems: [WorkItem] {
        var items = allItems
        if let status = filterStatus {
            items = items.filter { $0.status == status }
        }
        if let type = filterType {
            items = items.filter { $0.itemType == type }
        }
        return items.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Work Items")
                    .font(.headline)

                Spacer()

                filterPicker

                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
            }

            if filteredItems.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
        .padding()
        .sheet(isPresented: $showAddSheet) {
            AddWorkItemSheet(projectPath: projectPath ?? "") { item in
                modelContext.insert(item)
            }
        }
    }

    private var filterPicker: some View {
        HStack(spacing: 8) {
            Picker("Status", selection: $filterStatus) {
                Text("All").tag(nil as String?)
                Text("Todo").tag("todo" as String?)
                Text("In Progress").tag("in_progress" as String?)
                Text("Done").tag("done" as String?)
                Text("Blocked").tag("blocked" as String?)
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Picker("Type", selection: $filterType) {
                Text("All").tag(nil as String?)
                Text("Task").tag("task" as String?)
                Text("Bug").tag("bug" as String?)
                Text("Feature").tag("feature" as String?)
            }
            .pickerStyle(.menu)
            .frame(width: 80)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No work items")
                .foregroundStyle(.secondary)
            Button("Add Item") {
                showAddSheet = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var itemsList: some View {
        List {
            ForEach(filteredItems) { item in
                WorkItemRow(item: item) {
                    toggleStatus(item)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(.plain)
    }

    private func toggleStatus(_ item: WorkItem) {
        switch item.status {
        case "todo":
            item.status = "in_progress"
        case "in_progress":
            item.status = "done"
            item.completedAt = Date()
        case "done":
            item.status = "todo"
            item.completedAt = nil
        default:
            item.status = "todo"
        }
        item.updatedAt = Date()
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            modelContext.delete(item)
        }
    }
}

struct WorkItemRow: View {
    let item: WorkItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.body)
                        .strikethrough(item.status == "done")

                    typeTag
                }

                if let desc = item.descriptionText {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            priorityIndicator
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch item.status {
        case "done": return "checkmark.circle.fill"
        case "in_progress": return "arrow.circlepath"
        case "blocked": return "xmark.circle"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case "done": return .green
        case "in_progress": return .blue
        case "blocked": return .red
        default: return .secondary
        }
    }

    private var typeTag: some View {
        Text(item.itemType.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(typeColor.opacity(0.2))
            .foregroundStyle(typeColor)
            .clipShape(Capsule())
    }

    private var typeColor: Color {
        switch item.itemType {
        case "bug": return .red
        case "feature": return .purple
        case "improvement": return .orange
        default: return .blue
        }
    }

    private var priorityIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(i < item.priority ? Color.secondary.opacity(0.3) : Color.yellow)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

struct AddWorkItemSheet: View {
    let projectPath: String
    let onAdd: (WorkItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var itemType = "task"
    @State private var priority = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Work Item")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Description", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            HStack {
                Picker("Type", selection: $itemType) {
                    Text("Task").tag("task")
                    Text("Bug").tag("bug")
                    Text("Feature").tag("feature")
                    Text("Improvement").tag("improvement")
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("Priority")
                Stepper(value: $priority, in: 1...5) {
                    Text("\(priority)")
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add") {
                    let item = WorkItem(
                        projectPath: projectPath,
                        title: title,
                        descriptionText: description.isEmpty ? nil : description,
                        itemType: itemType,
                        priority: priority
                    )
                    onAdd(item)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    WorkItemsView(projectPath: "/tmp/test")
}
