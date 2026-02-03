import Foundation

@MainActor
final class FeatureFlags: ObservableObject {
    static let shared = FeatureFlags()

    @Published var storeKit = StoreKitManager.shared

    var canUseCloudSync: Bool { storeKit.isPro }
    var canShareReports: Bool { storeKit.isPro }
    var canUseWebDashboard: Bool { storeKit.isPro }
    var historyDays: Int { storeKit.isPro ? Int.max : 90 }

    var canUseiCloudSync: Bool { true }
    var canUseAIFeatures: Bool { true }
    var canUseTerminalTabs: Bool { true }
    var canUseAchievements: Bool { true }
    var canUseTimeTracking: Bool { true }
}
