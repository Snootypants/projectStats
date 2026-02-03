import Foundation
import SwiftData
#if canImport(GameKit)
import GameKit
#endif

@MainActor
final class AchievementService: ObservableObject {
    static let shared = AchievementService()

    @Published var unlockedAchievements: Set<Achievement> = []
    @Published var recentlyUnlocked: Achievement?

    private init() {
        loadUnlocked()
    }

    func loadUnlocked() {
        let context = AppModelContainer.shared.mainContext
        let unlocks = (try? context.fetch(FetchDescriptor<AchievementUnlock>())) ?? []
        unlockedAchievements = Set(unlocks.compactMap { Achievement(rawValue: $0.key) })
    }

    var mostRecentAchievement: Achievement? {
        let context = AppModelContainer.shared.mainContext
        var descriptor = FetchDescriptor<AchievementUnlock>(
            sortBy: [SortDescriptor(\.unlockedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let unlock = try? context.fetch(descriptor).first else { return nil }
        return Achievement(rawValue: unlock.key)
    }

    func checkAndUnlock(_ achievement: Achievement, projectPath: String? = nil) {
        guard !unlockedAchievements.contains(achievement) else { return }

        unlockedAchievements.insert(achievement)
        recentlyUnlocked = achievement

        let context = AppModelContainer.shared.mainContext
        let unlock = AchievementUnlock(key: achievement.rawValue, unlockedAt: Date(), projectPath: projectPath)
        context.insert(unlock)
        try? context.save()

        reportToGameCenter(achievement)
    }

    private func reportToGameCenter(_ achievement: Achievement) {
        #if canImport(GameKit)
        let gcAchievement = GKAchievement(identifier: achievement.rawValue)
        gcAchievement.percentComplete = 100
        gcAchievement.showsCompletionBanner = true
        GKAchievement.report([gcAchievement]) { error in
            if let error {
                print("Game Center error: \(error)")
            }
        }
        #endif

        if SettingsViewModel.shared.notifyAchievementUnlocked {
            NotificationService.shared.sendNotification(
                title: "Achievement Unlocked",
                message: "\(achievement.title) — \(achievement.description)"
            )
        }
    }
}
