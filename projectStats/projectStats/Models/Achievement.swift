import Foundation
import SwiftData

enum AchievementRarity: String, Codable, CaseIterable {
    case common
    case rare
    case epic
    case legendary
}

enum Achievement: String, CaseIterable, Codable {
    // Commits
    case firstBlood = "first_blood"
    case centurion = "centurion"
    case prolific = "prolific"

    // Streaks
    case weekWarrior = "week_warrior"
    case monthlyMaster = "monthly_master"
    case streakSurvivor = "streak_survivor"

    // Time
    case nightOwl = "night_owl"
    case earlyBird = "early_bird"
    case marathoner = "marathoner"
    case sprinter = "sprinter"

    // Lines
    case novelist = "novelist"
    case minimalist = "minimalist"
    case refactorer = "refactorer"

    // Projects
    case multiTasker = "multi_tasker"
    case focused = "focused"
    case launcher = "launcher"

    // Claude
    case aiWhisperer = "ai_whisperer"
    case contextMaster = "context_master"
    case promptEngineer = "prompt_engineer"

    // Social
    case shipper = "shipper"
    case collaborator = "collaborator"

    // Monetization
    case proSupporter = "pro_supporter"

    var title: String {
        switch self {
        case .firstBlood: return "First Blood"
        case .centurion: return "Centurion"
        case .prolific: return "Prolific"
        case .weekWarrior: return "Week Warrior"
        case .monthlyMaster: return "Monthly Master"
        case .streakSurvivor: return "Streak Survivor"
        case .nightOwl: return "Night Owl"
        case .earlyBird: return "Early Bird"
        case .marathoner: return "Marathoner"
        case .sprinter: return "Sprinter"
        case .novelist: return "Novelist"
        case .minimalist: return "Minimalist"
        case .refactorer: return "Refactorer"
        case .multiTasker: return "Multi-Tasker"
        case .focused: return "Focused"
        case .launcher: return "Launcher"
        case .aiWhisperer: return "AI Whisperer"
        case .contextMaster: return "Context Master"
        case .promptEngineer: return "Prompt Engineer"
        case .shipper: return "Shipper"
        case .collaborator: return "Collaborator"
        case .proSupporter: return "Pro Supporter"
        }
    }

    var description: String {
        switch self {
        case .firstBlood: return "First commit of the day"
        case .centurion: return "100 commits in a month"
        case .prolific: return "1000 total commits"
        case .weekWarrior: return "7 day coding streak"
        case .monthlyMaster: return "30 day coding streak"
        case .streakSurvivor: return "Recovered from a broken streak"
        case .nightOwl: return "Coded past midnight 5 times"
        case .earlyBird: return "Coded before 6am 5 times"
        case .marathoner: return "8+ hours in one day"
        case .sprinter: return "Ship a feature in under 1 hour"
        case .novelist: return "Write 10,000 lines in a week"
        case .minimalist: return "Delete more than you add in a week"
        case .refactorer: return "Refactor 1,000+ lines"
        case .multiTasker: return "Work on 5 projects in one day"
        case .focused: return "Work on 1 project for a week straight"
        case .launcher: return "Complete a project"
        case .aiWhisperer: return "100 Claude sessions"
        case .contextMaster: return "Hit 90% context without errors"
        case .promptEngineer: return "Create 50 prompts"
        case .shipper: return "Push to production on Friday"
        case .collaborator: return "Generate a report for someone"
        case .proSupporter: return "Subscribed to Pro"
        }
    }

    var icon: String {
        switch self {
        case .nightOwl: return "moon.stars.fill"
        case .earlyBird: return "sunrise.fill"
        case .marathoner: return "figure.run"
        case .sprinter: return "bolt.fill"
        case .novelist: return "book.fill"
        case .minimalist: return "scissors"
        case .refactorer: return "wand.and.stars"
        case .weekWarrior: return "flame.fill"
        case .monthlyMaster: return "calendar"
        case .streakSurvivor: return "lifepreserver"
        case .firstBlood: return "drop.fill"
        case .centurion: return "100.circle"
        case .prolific: return "chart.bar.fill"
        case .multiTasker: return "square.grid.2x2"
        case .focused: return "scope"
        case .launcher: return "rocket.fill"
        case .aiWhisperer: return "sparkles"
        case .contextMaster: return "gauge"
        case .promptEngineer: return "text.bubble.fill"
        case .shipper: return "shippingbox.fill"
        case .collaborator: return "person.2.fill"
        case .proSupporter: return "star.fill"
        }
    }

    var points: Int {
        switch rarity {
        case .common: return 25
        case .rare: return 50
        case .epic: return 100
        case .legendary: return 200
        }
    }

    var rarity: AchievementRarity {
        switch self {
        case .firstBlood, .weekWarrior, .nightOwl, .earlyBird, .promptEngineer:
            return .common
        case .centurion, .marathoner, .sprinter, .novelist, .minimalist, .shipper, .collaborator:
            return .rare
        case .prolific, .monthlyMaster, .refactorer, .multiTasker, .focused, .aiWhisperer, .contextMaster:
            return .epic
        case .launcher, .proSupporter, .streakSurvivor:
            return .legendary
        }
    }
}

@Model
final class AchievementUnlock {
    var id: UUID
    var key: String
    var unlockedAt: Date
    var projectPath: String?

    init(id: UUID = UUID(), key: String, unlockedAt: Date = Date(), projectPath: String? = nil) {
        self.id = id
        self.key = key
        self.unlockedAt = unlockedAt
        self.projectPath = projectPath
    }
}
