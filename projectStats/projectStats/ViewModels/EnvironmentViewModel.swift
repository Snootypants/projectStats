import Foundation
import SwiftUI

@MainActor
final class EnvironmentViewModel: ObservableObject {
    @Published var variables: [EnvironmentVariable] = []
    @Published var searchText: String = ""
    @Published var statusMessage: String?
    @Published var availableKeychainKeys: [String] = []
    @Published var isApplying = false

    private let projectPath: URL
    private let envFileService = EnvFileService()
    private let keychainService = KeychainService.shared
    private var keychainCache: [String: String] = [:]
    private var missingKeychainKeys: Set<String> = []

    private let commonSuggestedKeys: [String] = [
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "GITHUB_TOKEN",
        "GITHUB_PAT",
        "STRIPE_SECRET_KEY",
        "STRIPE_PUBLISHABLE_KEY",
        "DATABASE_URL",
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY",
        "SENDGRID_API_KEY",
        "TWILIO_ACCOUNT_SID",
        "TWILIO_AUTH_TOKEN",
        "NODE_ENV"
    ]

    init(projectPath: URL) {
        self.projectPath = projectPath
    }

    var filteredIndices: [Int] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return Array(variables.indices)
        }

        return variables.indices.filter { index in
            variables[index].key.lowercased().contains(trimmed)
        }
    }

    func load() {
        refreshKeychainKeys()

        let envVars = envFileService.parseEnvFile(at: envURL)
        let exampleKeys = envFileService.parseEnvExample(at: envExampleURL)
        variables = merge(envVariables: envVars, exampleKeys: exampleKeys)

        if variables.isEmpty, !exampleKeys.isEmpty {
            variables = exampleKeys.map { key in
                EnvironmentVariable(key: key, value: "", isEnabled: false, source: .imported)
            }
        }
    }

    func refreshKeychainKeys() {
        let keys = keychainService.listAvailableKeys()
        let merged = Array(Set(keys + commonSuggestedKeys)).sorted()
        availableKeychainKeys = merged
        keychainCache.removeAll()
        missingKeychainKeys.removeAll()
    }

    func addVariable() {
        variables.append(EnvironmentVariable(key: "", value: "", isEnabled: true, source: .manual))
    }

    func importEnvExample() {
        guard FileManager.default.fileExists(atPath: envExampleURL.path) else {
            statusMessage = "No .env.example found in this project."
            return
        }
        let exampleKeys = envFileService.parseEnvExample(at: envExampleURL)
        variables = merge(envVariables: variables, exampleKeys: exampleKeys)
    }

    func importEnvFile(named fileName: String) {
        let url = projectPath.appendingPathComponent(fileName)
        importEnvFile(at: url)
    }

    func importEnvFile(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            statusMessage = "No file found at \(url.lastPathComponent)."
            return
        }

        let imported = envFileService.parseEnvFile(at: url)
        mergeImported(variables: imported)
    }

    func apply() {
        statusMessage = nil
        isApplying = true
        defer { isApplying = false }

        var toWrite: [EnvironmentVariable] = []
        var missingKeys: [String] = []

        for variable in variables where variable.isEnabled {
            var resolved = variable
            if variable.source == .keychain {
                let key = variable.keychainKey ?? variable.key
                if let secret = keychainValue(for: key) {
                    resolved.value = secret
                } else {
                    missingKeys.append(key)
                    continue
                }
            }
            if resolved.value.isEmpty {
                continue
            }
            toWrite.append(resolved)
        }

        do {
            try envFileService.writeEnvFile(variables: toWrite, to: envURL)
            try envFileService.ensureGitignore(in: projectPath)
            if missingKeys.isEmpty {
                statusMessage = "Wrote .env with \(toWrite.count) variables."
            } else {
                statusMessage = "Wrote .env, but missing Keychain values for: \(missingKeys.joined(separator: ", "))."
            }
        } catch {
            statusMessage = "Failed to write .env: \(error.localizedDescription)"
        }
    }

    func resolvedValue(for variable: EnvironmentVariable) -> String? {
        switch variable.source {
        case .manual, .imported:
            return variable.value
        case .keychain:
            let key = variable.keychainKey ?? variable.key
            return keychainValue(for: key)
        }
    }

    func isKeychainMissing(for variable: EnvironmentVariable) -> Bool {
        guard variable.source == .keychain else { return false }
        let key = variable.keychainKey ?? variable.key
        return keychainValue(for: key) == nil
    }

    func updateSource(for index: Int, to source: VariableSource) {
        guard variables.indices.contains(index) else { return }
        variables[index].source = source
        switch source {
        case .keychain:
            let candidate = variables[index].key
            if availableKeychainKeys.contains(candidate) {
                variables[index].keychainKey = candidate
            } else {
                variables[index].keychainKey = availableKeychainKeys.first
            }
        case .manual, .imported:
            variables[index].keychainKey = nil
        }
    }

    private var envURL: URL {
        projectPath.appendingPathComponent(".env")
    }

    private var envExampleURL: URL {
        projectPath.appendingPathComponent(".env.example")
    }

    private func merge(envVariables: [EnvironmentVariable], exampleKeys: [String]) -> [EnvironmentVariable] {
        var merged: [EnvironmentVariable] = []
        var existingMap: [String: EnvironmentVariable] = [:]
        for variable in envVariables {
            existingMap[variable.key] = variable
        }

        var usedKeys = Set<String>()
        let keychainSet = Set(availableKeychainKeys)

        for key in exampleKeys {
            if let existing = existingMap[key] {
                merged.append(existing)
            } else if keychainSet.contains(key) {
                merged.append(EnvironmentVariable(
                    key: key,
                    value: "",
                    isEnabled: true,
                    source: .keychain,
                    keychainKey: key
                ))
            } else {
                merged.append(EnvironmentVariable(
                    key: key,
                    value: "",
                    isEnabled: false,
                    source: .imported
                ))
            }
            usedKeys.insert(key)
        }

        for variable in envVariables where !usedKeys.contains(variable.key) {
            merged.append(variable)
        }

        return merged
    }

    private func mergeImported(variables imported: [EnvironmentVariable]) {
        var existingMap: [String: Int] = [:]
        for (index, variable) in variables.enumerated() {
            existingMap[variable.key] = index
        }

        for importedVar in imported {
            if let index = existingMap[importedVar.key] {
                variables[index].value = importedVar.value
                variables[index].isEnabled = true
                variables[index].source = .imported
            } else {
                variables.append(importedVar)
            }
        }
    }

    private func keychainValue(for key: String) -> String? {
        if let cached = keychainCache[key] {
            return cached
        }
        if missingKeychainKeys.contains(key) {
            return nil
        }

        let value = keychainService.getSecret(forKey: key)
        if let value {
            keychainCache[key] = value
            return value
        }

        missingKeychainKeys.insert(key)
        return nil
    }
}
