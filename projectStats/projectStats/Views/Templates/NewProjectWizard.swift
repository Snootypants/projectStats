import SwiftUI

struct NewProjectWizard: View {
    @State private var projectName = ""
    @State private var location = "~/Code"
    @State private var selectedTemplate = "Next.js"
    @State private var temperament = "Balanced"
    @State private var initGit = true
    @State private var initClaude = true
    @State private var initProjectStats = true

    private let templates = ["Swift/iOS", "Next.js", "Python", "Monorepo", "From Existing"]
    private let temperaments = ["Strict", "Balanced", "Fast", "Teaching", "Senior Dev"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Project")
                .font(.title2)

            Form {
                TextField("Project Name", text: $projectName)
                TextField("Location", text: $location)

                Picker("Template", selection: $selectedTemplate) {
                    ForEach(templates, id: \.self) { template in
                        Text(template).tag(template)
                    }
                }

                Picker("Claude Temperament", selection: $temperament) {
                    ForEach(temperaments, id: \.self) { temp in
                        Text(temp).tag(temp)
                    }
                }

                Toggle("Git repository", isOn: $initGit)
                Toggle("CLAUDE.md", isOn: $initClaude)
                Toggle("projectstats.json", isOn: $initProjectStats)
            }

            HStack {
                Spacer()
                Button("Cancel") {}
                Button("Create Project") {}
            }
        }
        .padding()
        .frame(minWidth: 520)
    }
}

#Preview {
    NewProjectWizard()
}
