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
    @AppStorage(AppStorageKeys.achievementNightOwlCount) private var nightOwlCount: Int = 0
    @AppStorage(AppStorageKeys.achievementEarlyBirdCount) private var earlyBirdCount: Int = 0
    @AppStorage(AppStorageKeys.achievementLastCommitDate) private var lastCommitDateString: String = ""

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
                Log.xp.error("Game Center error: \(error)")
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

    /// Check and unlock first commit of the day achievement + daily XP
    func checkFirstCommitOfDay(projectPath: String) {
        let todayString = formatDate(Date())

        // If we already committed today, this isn't the first
        if lastCommitDateString == todayString {
            return
        }

        // This is the first commit today!
        lastCommitDateString = todayString

        // One-time achievement unlock
        checkAndUnlock(.firstBlood, projectPath: projectPath)

        // Daily XP bonus (fires every day, not just first unlock)
        XPService.shared.checkDailyBonus()

        // Check streak achievements
        checkStreakAchievements(projectPath: projectPath)

        Log.xp.info("[Achievements] First commit of the day processed")
    }

    /// Check time-based achievements (night owl, early bird)
    func checkTimeBasedAchievements(projectPath: String) {
        let hour = Calendar.current.component(.hour, from: Date())

        // Night Owl - coding past midnight (12am - 5am)
        if hour >= 0 && hour < 5 {
            nightOwlCount += 1
            Log.xp.debug("[Achievements] Night owl count: \(self.nightOwlCount)")
            if nightOwlCount >= 5 {
                checkAndUnlock(.nightOwl, projectPath: projectPath)
            }
        }

        // Early Bird - coding before 6am (4am - 6am to distinguish from night owl)
        if hour >= 4 && hour < 6 {
            earlyBirdCount += 1
            Log.xp.debug("[Achievements] Early bird count: \(self.earlyBirdCount)")
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
            Log.xp.info("[Achievements] Shipper unlocked - Friday deploy!")
        }
    }

    /// Check commit count achievements
    func checkCommitCountAchievements(projectPath: String) {
        let path = URL(fileURLWithPath: projectPath)

        // Get total commit count
        let totalCommits = GitService.shared.getCommitCount(at: path)

        if totalCommits >= 1000 {
            checkAndUnlock(.prolific, projectPath: projectPath)
            Log.xp.info("[Achievements] Prolific unlocked - 1000 total commits!")
        }

        // Get commits this month
        let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))
        let monthlyCommits = GitService.shared.getCommitCount(at: path, since: startOfMonth)

        if monthlyCommits >= 100 {
            checkAndUnlock(.centurion, projectPath: projectPath)
            Log.xp.info("[Achievements] Centurion unlocked - 100 commits this month!")
        }
    }

    /// Called when a git push is detected - runs all relevant achievement checks
    func onGitPushDetected(projectPath: String) {
        Log.xp.info("[Achievements] Git push detected, checking achievements for: \(projectPath)")

        checkFirstCommitOfDay(projectPath: projectPath)
        checkTimeBasedAchievements(projectPath: projectPath)
        checkFridayDeploy(projectPath: projectPath)
        checkCommitCountAchievements(projectPath: projectPath)
    }

    // MARK: - Streak Achievements

    /// Check streak-based achievements (called from checkFirstCommitOfDay)
    func checkStreakAchievements(projectPath: String) {
        let streak = XPService.shared.currentStreak
        if streak >= 7 { checkAndUnlock(.weekWarrior, projectPath: projectPath) }
        if streak >= 30 { checkAndUnlock(.monthlyMaster, projectPath: projectPath) }
    }

    // MARK: - Session Achievements

    /// Check AI session count achievements (called on Claude session end)
    func checkSessionAchievements(projectPath: String) {
        let context = AppModelContainer.shared.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<AISessionV2>())) ?? 0
        if count >= 100 { checkAndUnlock(.aiWhisperer, projectPath: projectPath) }
    }

    // MARK: - Prompt Achievements

    /// Check prompt count achievements (called on prompt save)
    func checkPromptAchievements(projectPath: String) {
        let context = AppModelContainer.shared.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<SavedPrompt>())) ?? 0
        if count >= 50 { checkAndUnlock(.promptEngineer, projectPath: projectPath) }
    }

    // MARK: - Time Achievements

    /// Check daily time achievements (called on Claude session end)
    func checkDailyTimeAchievements(projectPath: String) {
        let todaySeconds = TimeTrackingService.shared.todayHumanTotal + TimeTrackingService.shared.todayAITotal
        if todaySeconds >= 8 * 3600 { checkAndUnlock(.marathoner, projectPath: projectPath) }
    }

    // MARK: - Speed Achievement

    /// Check sprinter achievement (feature shipped in under 1 hour)
    func checkSprinterAchievement(promptDuration: Double, projectPath: String) {
        if promptDuration > 0 && promptDuration < 3600 {
            checkAndUnlock(.sprinter, projectPath: projectPath)
        }
    }

    // MARK: - Line Count Achievements

    /// Check line count achievements (called during dashboard sync)
    func checkLineCountAchievements(projectPath: String, weeklyLinesAdded: Int, weeklyLinesRemoved: Int) {
        if weeklyLinesAdded >= 10_000 { checkAndUnlock(.novelist, projectPath: projectPath) }
        if weeklyLinesRemoved > weeklyLinesAdded { checkAndUnlock(.minimalist, projectPath: projectPath) }
        if weeklyLinesRemoved >= 1_000 { checkAndUnlock(.refactorer, projectPath: projectPath) }
    }

    // MARK: - Project Diversity Achievements

    /// Check multi-project and focus achievements (called during dashboard refresh)
    func checkProjectDiversityAchievements() {
        let context = AppModelContainer.shared.mainContext
        let today = Calendar.current.startOfDay(for: Date())
        let activities = (try? context.fetch(FetchDescriptor<CachedDailyActivity>())) ?? []

        // Multi-Tasker: 5 projects in one day
        let todayActivities = activities.filter { Calendar.current.isDate($0.date, inSameDayAs: today) && $0.commits > 0 }
        let uniqueProjects = Set(todayActivities.map { $0.projectPath })
        if uniqueProjects.count >= 5 { checkAndUnlock(.multiTasker) }

        // Focused: 1 project for 7 days straight
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today) else { return }
        let weekActivities = activities.filter { $0.date >= weekAgo && $0.commits > 0 }
        let weekProjects = Set(weekActivities.map { $0.projectPath })
        if weekProjects.count == 1 && weekActivities.count >= 7 {
            checkAndUnlock(.focused, projectPath: weekProjects.first)
        }
    }

    // TODO: Context Master achievement — needs parsing context % from terminal output
    // and tracking "no errors in session" state. Skipping for now per spec guidance.

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
