import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(1)

            GitHubSettingsView()
                .tabItem {
                    Label("GitHub", systemImage: "link")
                }
                .tag(2)

            MessagingSettingsView()
                .tabItem {
                    Label("Messaging", systemImage: "message")
                }
                .tag(3)

            CloudSyncSettingsView()
                .tabItem {
                    Label("Cloud Sync", systemImage: "icloud")
                }
                .tag(4)

            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(5)

            DataManagementView()
                .tabItem {
                    Label("Data", systemImage: "tray.full")
                }
                .tag(6)

            NotificationSettingsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
                .tag(7)

            SubscriptionView()
                .tabItem {
                    Label("Subscription", systemImage: "creditcard")
                }
                .tag(8)

            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
                .tag(9)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(10)
        }
        .environmentObject(viewModel)
        .frame(width: 560, height: 420)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Code Directory", text: .constant(viewModel.codeDirectory.path))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)

                    Button("Browse...") {
                        viewModel.selectCodeDirectory()
                    }
                }

                Picker("Default Editor", selection: $viewModel.defaultEditor) {
                    ForEach(Editor.allCases, id: \.self) { editor in
                        Label(editor.rawValue, systemImage: editor.icon)
                            .tag(editor)
                    }
                }

                Picker("Default Terminal", selection: $viewModel.defaultTerminal) {
                    ForEach(Terminal.allCases, id: \.self) { terminal in
                        Text(terminal.rawValue).tag(terminal)
                    }
                }

                Stepper("Refresh Interval: \(viewModel.refreshInterval) min", value: $viewModel.refreshInterval, in: 5...60, step: 5)
            }

            Section {
                Toggle("Launch at Login", isOn: $viewModel.launchAtLogin)
                Toggle("Show in Dock", isOn: $viewModel.showInDock)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker("Theme", selection: $viewModel.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Theme")
            } footer: {
                Text("Choose your preferred appearance for the app.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct GitHubSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showToken = false
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                HStack {
                    if showToken {
                        TextField("GitHub Token", text: $viewModel.githubToken)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("GitHub Token", text: $viewModel.githubToken)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("Success") ? .green : .red)
                }

                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(viewModel.githubToken.isEmpty || isTesting)

                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    Link("Create Token", destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:user")!)
                }
            } header: {
                Text("Personal Access Token")
            } footer: {
                Text("Optional. Allows fetching additional repository information like stars and forks. Requires 'repo' scope.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                // Test by fetching user info
                let url = URL(string: "https://api.github.com/user")!
                var request = URLRequest(url: url)
                request.setValue("Bearer \(viewModel.githubToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        testResult = "Success! Token is valid."
                    } else if httpResponse.statusCode == 401 {
                        testResult = "Error: Invalid token."
                    } else {
                        testResult = "Error: HTTP \(httpResponse.statusCode)"
                    }
                }
            } catch {
                testResult = "Error: \(error.localizedDescription)"
            }

            isTesting = false
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("ProjectStats")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("A developer dashboard for tracking your coding activity across all projects.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()

            HStack {
                Link("GitHub", destination: URL(string: "https://github.com/Snootypants/projectStats")!)
                Text("•")
                    .foregroundStyle(.secondary)
                Link("Report Issue", destination: URL(string: "https://github.com/Snootypants/projectStats/issues")!)
            }
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel.shared)
        .environmentObject(DashboardViewModel.shared)
}
