import SwiftUI

struct EnvironmentVariableRow: View {
    @Binding var variable: EnvironmentVariable
    let resolvedValue: String?
    let keychainMissing: Bool
    let availableKeychainKeys: [String]
    let onSourceChange: (VariableSource) -> Void

    @State private var isRevealed = false
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $variable.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)

            TextField("KEY_NAME", text: $variable.key)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .textFieldStyle(.plain)
                .frame(minWidth: 180, maxWidth: 240)

            valueView

            Spacer()

            if variable.source == .keychain {
                keychainPicker
            }

            sourcePicker

            if keychainMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("Key not found in Keychain")
            }
        }
        .padding(.vertical, 6)
    }

    private var valueView: some View {
        HStack(spacing: 6) {
            if variable.source == .keychain {
                valueText
                Button(isRevealed ? "Hide" : "Reveal") {
                    isRevealed.toggle()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                if isEditing {
                    TextField("Value", text: $variable.value)
                        .font(.system(size: 12, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                } else {
                    valueText
                }
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                    if !isEditing {
                        isRevealed = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
    }

    private var valueText: some View {
        let rawValue = resolvedValue ?? ""
        let displayValue: String
        let isEmptyValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if isEmptyValue {
            displayValue = "(not set)"
        } else if isRevealed {
            displayValue = rawValue
        } else {
            displayValue = maskedValue(for: rawValue)
        }

        return Text(displayValue)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(isEmptyValue ? .secondary : .primary)
            .lineLimit(1)
            .frame(maxWidth: 240, alignment: .leading)
    }

    private var sourcePicker: some View {
        let binding = Binding<VariableSource>(
            get: { variable.source },
            set: { newValue in
                variable.source = newValue
                onSourceChange(newValue)
            }
        )

        return Picker("Source", selection: binding) {
            ForEach(VariableSource.allCases) { source in
                Label(source.label, systemImage: source.iconName)
                    .tag(source)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 120)
    }

    private var keychainPicker: some View {
        let binding = Binding<String>(
            get: { variable.keychainKey ?? "" },
            set: { newValue in
                variable.keychainKey = newValue.isEmpty ? nil : newValue
            }
        )

        return Picker("Keychain", selection: binding) {
            Text("Select Key").tag("")
            ForEach(availableKeychainKeys, id: \.self) { key in
                Text(key).tag(key)
            }
        }
        .labelsHidden()
        .frame(maxWidth: 220)
    }

    private func maskedValue(for value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= 10 {
            return String(repeating: "•", count: max(6, trimmed.count))
        }
        let suffix = trimmed.suffix(7)
        let maskCount = min(8, max(6, trimmed.count - 7))
        return String(repeating: "•", count: maskCount) + suffix
    }
}
