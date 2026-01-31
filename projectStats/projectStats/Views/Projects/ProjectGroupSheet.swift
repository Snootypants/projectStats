import SwiftUI

struct ProjectGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var groupStore = ProjectGroupStore.shared
    let projects: [Project]
    let onComplete: () -> Void

    @State private var groupName: String = ""
    @State private var selectedProjectPaths: Set<String> = []
    @State private var mode: Mode = .create

    enum Mode {
        case create
        case addToExisting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Combine Projects")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Mode selector
            Picker("Mode", selection: $mode) {
                Text("Create New Group").tag(Mode.create)
                Text("Add to Existing").tag(Mode.addToExisting)
            }
            .pickerStyle(.segmented)
            .padding()

            if mode == .create {
                createNewGroupView
            } else {
                addToExistingView
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Done") {
                    performAction()
                    onComplete()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canComplete)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
        .onAppear {
            // Pre-select passed projects
            selectedProjectPaths = Set(projects.map { $0.path.path })
        }
    }

    private var createNewGroupView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Group name input
            VStack(alignment: .leading, spacing: 4) {
                Text("Group Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("e.g., My App (Frontend + Backend)", text: $groupName)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            // Project selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Select Projects to Combine")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                projectSelectionList
            }
        }
        .padding(.vertical)
    }

    private var addToExistingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if groupStore.groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No existing groups")
                        .font(.headline)
                    Text("Create a new group first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Existing groups list
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select a Group")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    List(groupStore.groups, selection: $selectedGroupId) { group in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(group.name)
                                    .font(.body)
                                Text("\(group.projectPaths.count) projects")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedGroupId == group.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedGroupId = group.id
                        }
                    }
                    .listStyle(.inset)
                }

                Divider()

                // Projects to add
                VStack(alignment: .leading, spacing: 4) {
                    Text("Projects to Add")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    projectSelectionList
                }
            }
        }
        .padding(.vertical)
    }

    @State private var selectedGroupId: UUID?

    private var projectSelectionList: some View {
        List {
            ForEach(projects) { project in
                HStack {
                    Image(systemName: selectedProjectPaths.contains(project.path.path) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedProjectPaths.contains(project.path.path) ? .blue : .secondary)

                    VStack(alignment: .leading) {
                        Text(project.name)
                            .font(.body)
                        Text(project.path.path)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let language = project.language {
                        Text(language)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedProjectPaths.contains(project.path.path) {
                        selectedProjectPaths.remove(project.path.path)
                    } else {
                        selectedProjectPaths.insert(project.path.path)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var canComplete: Bool {
        if mode == .create {
            return !groupName.isEmpty && selectedProjectPaths.count >= 2
        } else {
            return selectedGroupId != nil && !selectedProjectPaths.isEmpty
        }
    }

    private func performAction() {
        if mode == .create {
            groupStore.createGroup(name: groupName, projectPaths: Array(selectedProjectPaths))
        } else if let groupId = selectedGroupId {
            for path in selectedProjectPaths {
                groupStore.addToGroup(groupId, projectPath: path)
            }
        }
    }
}

// MARK: - Manage Groups View
struct ManageGroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var groupStore = ProjectGroupStore.shared
    @State private var editingGroup: ProjectGroup?
    @State private var editedName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Manage Groups")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            if groupStore.groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No groups yet")
                        .font(.headline)
                    Text("Combine projects from the Projects tab")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(groupStore.groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if editingGroup?.id == group.id {
                                    TextField("Group name", text: $editedName, onCommit: {
                                        groupStore.renameGroup(group.id, newName: editedName)
                                        editingGroup = nil
                                    })
                                    .textFieldStyle(.roundedBorder)
                                } else {
                                    Text(group.name)
                                        .font(.headline)
                                }

                                Spacer()

                                Button {
                                    editingGroup = group
                                    editedName = group.name
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)

                                Button {
                                    groupStore.deleteGroup(group.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }

                            ForEach(group.projectPaths, id: \.self) { path in
                                HStack {
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Button {
                                        groupStore.removeFromGroup(group.id, projectPath: path)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.red)
                                }
                                .padding(.leading, 16)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 400, height: 450)
    }
}
