import Foundation
import SwiftUI

@MainActor
final class XPService: ObservableObject {
    static let shared = XPService()

    @AppStorage("xp.totalXP") var totalXP: Int = 0
    @AppStorage("xp.currentLevel") var currentLevel: Int = 1
    @AppStorage("xp.lastDailyBonusDate") private var lastDailyBonusDate: String = ""
    @AppStorage("xp.currentStreak") var currentStreak: Int = 0
    @AppStorage("xp.lastStreakDate") private var lastStreakDate: String = ""

    @Published var recentXPGain: (amount: Int, reason: String)?

    // XP amounts
    static let xpPerCommit = 5
    static let xpPerPush = 10
    static let xpPerPromptExecuted = 10
    static let xpPerClaudeSession = 5
    static let xpDailyBonus = 15
    static let xpPerHourCoding = 10

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {}

    // MARK: - Level Calculations

    /// Total XP needed to reach the next level
    var xpForNextLevel: Int {
        currentLevel * 250
    }

    /// XP earned within the current level bracket
    var xpProgressInLevel: Int {
        totalXP - (currentLevel - 1) * 250
    }

    /// Streak multiplier: day 1-2: 1.0, day 3-6: 1.5, day 7+: 2.0
    var streakMultiplier: Double {
        if currentStreak >= 7 { return 2.0 }
        if currentStreak >= 3 { return 1.5 }
        return 1.0
    }

    // MARK: - XP Award

    func awardXP(amount: Int, reason: String) {
        let multiplied = Int(Double(amount) * streakMultiplier)
        let previousLevel = currentLevel

        totalXP += multiplied
        currentLevel = max(1, (totalXP / 250) + 1)

        recentXPGain = (amount: multiplied, reason: reason)

        // Auto-clear after 3 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.recentXPGain?.reason == reason {
                self.recentXPGain = nil
            }
        }

        // Level up notification
        if currentLevel > previousLevel {
            NotificationService.shared.sendNotification(
                title: "Level Up!",
                message: "You reached Level \(currentLevel)!"
            )
        }
    }

    // MARK: - Activity Triggers

    func onCommitDetected(projectPath: String) {
        awardXP(amount: Self.xpPerCommit, reason: "Commit")
        checkDailyBonus()
    }

    func onPushDetected(projectPath: String) {
        awardXP(amount: Self.xpPerPush, reason: "Push")
        checkDailyBonus()
    }

    func onPromptExecuted(projectPath: String) {
        awardXP(amount: Self.xpPerPromptExecuted, reason: "Prompt")
        checkDailyBonus()
    }

    func onClaudeSessionCompleted(projectPath: String) {
        awardXP(amount: Self.xpPerClaudeSession, reason: "Claude session")
        checkDailyBonus()
    }

    // MARK: - Daily Bonus & Streak

    func checkDailyBonus() {
        let today = dateFormatter.string(from: Date())
        guard lastDailyBonusDate != today else { return }

        lastDailyBonusDate = today
        updateStreak()
        awardXP(amount: Self.xpDailyBonus, reason: "Daily bonus")
    }

    func updateStreak() {
        let today = dateFormatter.string(from: Date())

        if lastStreakDate == today {
            return // Already counted today
        }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayString = dateFormatter.string(from: yesterday)

        let previousStreak = currentStreak

        if lastStreakDate == yesterdayString {
            currentStreak += 1
        } else {
            // Streak broken — check if we had a long streak for streakSurvivor achievement
            if previousStreak >= 7 {
                UserDefaults.standard.set(true, forKey: "achievement.hadLongStreak")
            }
            currentStreak = 1
        }

        lastStreakDate = today

        // Check streakSurvivor: recovered from broken streak
        if currentStreak >= 3 && UserDefaults.standard.bool(forKey: "achievement.hadLongStreak") {
            AchievementService.shared.checkAndUnlock(.streakSurvivor)
            UserDefaults.standard.set(false, forKey: "achievement.hadLongStreak")
        }
    }
}
