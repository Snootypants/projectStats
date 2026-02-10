import SwiftData
import Foundation

@MainActor
class SettingsStoreService: ObservableObject {
    static let shared = SettingsStoreService()

    // Cache for fast reads
    private var cache: [String: String] = [:]
    private var loaded = false

    func loadIfNeeded() {
        guard !loaded else { return }
        let context = AppModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<AppSetting>()
        if let settings = try? context.fetch(descriptor) {
            for setting in settings {
                cache[setting.key] = setting.value
            }
        }
        loaded = true
    }

    func get(_ key: String, default defaultValue: String = "") -> String {
        loadIfNeeded()
        return cache[key] ?? defaultValue
    }

    func getBool(_ key: String, default defaultValue: Bool = false) -> Bool {
        loadIfNeeded()
        return cache[key].flatMap { Bool($0) } ?? defaultValue
    }

    func getInt(_ key: String, default defaultValue: Int = 0) -> Int {
        loadIfNeeded()
        return cache[key].flatMap { Int($0) } ?? defaultValue
    }

    func getDouble(_ key: String, default defaultValue: Double = 0) -> Double {
        loadIfNeeded()
        return cache[key].flatMap { Double($0) } ?? defaultValue
    }

    func set(_ key: String, value: String) {
        cache[key] = value
        let context = AppModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<AppSetting>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(descriptor).first {
            existing.value = value
            existing.updatedAt = Date()
        } else {
            context.insert(AppSetting(key: key, value: value))
        }
        context.safeSave()
    }

    func set(_ key: String, value: Bool) { set(key, value: String(value)) }
    func set(_ key: String, value: Int) { set(key, value: String(value)) }
    func set(_ key: String, value: Double) { set(key, value: String(value)) }
}
