import Foundation

enum VariableSource: String, CaseIterable, Codable, Identifiable {
    case keychain
    case manual
    case imported

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keychain: return "Keychain"
        case .manual: return "Manual"
        case .imported: return "Imported"
        }
    }

    var iconName: String {
        switch self {
        case .keychain: return "key.fill"
        case .manual: return "pencil"
        case .imported: return "tray.and.arrow.down"
        }
    }
}

struct EnvironmentVariable: Identifiable, Hashable {
    let id: UUID
    var key: String
    var value: String
    var isEnabled: Bool
    var source: VariableSource
    var keychainKey: String?

    init(
        id: UUID = UUID(),
        key: String,
        value: String = "",
        isEnabled: Bool = true,
        source: VariableSource = .manual,
        keychainKey: String? = nil
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
        self.source = source
        self.keychainKey = keychainKey
    }
}
