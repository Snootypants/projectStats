import Foundation
import SwiftUI
import SwiftData
#if canImport(GameKit)
import GameKit
#endif

@MainActor
final class AchievementService: ObservableObject {
    static let shared = AchievementService()

    @Published var unlockedAchievements: Set<Achievement> = []
    @Published var recentlyUnlocked: Achievement?

    // Progress tracking for incremental achievements
    @AppStorage("achievement.nightOwlCount") private var nightOwlCount: Int = 0
    @AppStorage("achievement.earlyBirdCount") private var earlyBirdCount: Int = 0
    @AppStorage("achievement.lastCommitDate") private var lastCommitDateString: String = ""

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

    // MARK: - Achievement Check Helpers

    /// Check and unlock first commit of the day achievement
    func checkFirstCommitOfDay(projectPath: String) {
        let todayString = formatDate(Date())

        // If we already committed today, this isn't the first
        if lastCommitDateString == todayString {
            return
        }

        // This is the first commit today!
        lastCommitDateString = todayString
        checkAndUnlock(.firstBlood, projectPath: projectPath)
        print("[Achievements] First Blood unlocked - first commit of the day!")
    }

    /// Check time-based achievements (night owl, early bird)
    func checkTimeBasedAchievements(projectPath: String) {
        let hour = Calendar.current.component(.hour, from: Date())

        // Night Owl - coding past midnight (12am - 5am)
        if hour >= 0 && hour < 5 {
            nightOwlCount += 1
            print("[Achievements] Night owl count: \(nightOwlCount)")
            if nightOwlCount >= 5 {
                checkAndUnlock(.nightOwl, projectPath: projectPath)
            }
        }

        // Early Bird - coding before 6am (4am - 6am to distinguish from night owl)
        if hour >= 4 && hour < 6 {
            earlyBirdCount += 1
            print("[Achievements] Early bird count: \(earlyBirdCount)")
            if earlyBirdCount >= 5 {
                checkAndUnlock(.earlyBird, projectPath: projectPath)
            }
        }
    }

    /// Check Friday deploy achievement
    func checkFridayDeploy(projectPath: String) {
        let weekday = Calendar.current.component(.weekday, from: Date())
        if weekday == 6 { // Friday (Sunday = 1, so Friday = 6)
            checkAndUnlock(.shipper, projectPath: projectPath)
            print("[Achievements] Shipper unlocked - Friday deploy!")
        }
    }

    /// Check commit count achievements
    func checkCommitCountAchievements(projectPath: String) {
        let path = URL(fileURLWithPath: projectPath)

        // Get total commit count
        let totalCommits = GitService.shared.getCommitCount(at: path)

        if totalCommits >= 1000 {
            checkAndUnlock(.prolific, projectPath: projectPath)
            print("[Achievements] Prolific unlocked - 1000 total commits!")
        }

        // Get commits this month
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))
        let monthlyCommits = GitService.shared.getCommitCount(at: path, since: startOfMonth)

        if monthlyCommits >= 100 {
            checkAndUnlock(.centurion, projectPath: projectPath)
            print("[Achievements] Centurion unlocked - 100 commits this month!")
        }
    }

    /// Called when a git push is detected - runs all relevant achievement checks
    func onGitPushDetected(projectPath: String) {
        print("[Achievements] Git push detected, checking achievements for: \(projectPath)")

        checkFirstCommitOfDay(projectPath: projectPath)
        checkTimeBasedAchievements(projectPath: projectPath)
        checkFridayDeploy(projectPath: projectPath)
        checkCommitCountAchievements(projectPath: projectPath)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
