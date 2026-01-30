import Foundation

struct ActivityStats: Identifiable {
    var id: Date { date }
    let date: Date
    var linesAdded: Int
    var linesRemoved: Int
    var commits: Int
    var projectPaths: Set<String>

    var totalLines: Int {
        linesAdded + linesRemoved
    }

    var netLines: Int {
        linesAdded - linesRemoved
    }

    init(date: Date, linesAdded: Int = 0, linesRemoved: Int = 0, commits: Int = 0, projectPaths: Set<String> = []) {
        self.date = date.startOfDay
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.commits = commits
        self.projectPaths = projectPaths
    }

    mutating func merge(with other: ActivityStats) {
        self.linesAdded += other.linesAdded
        self.linesRemoved += other.linesRemoved
        self.commits += other.commits
        self.projectPaths.formUnion(other.projectPaths)
    }
}

struct DailyStats {
    var linesAdded: Int = 0
    var linesRemoved: Int = 0
    var commits: Int = 0

    var totalLines: Int { linesAdded + linesRemoved }
}

struct AggregatedStats {
    let today: DailyStats
    let thisWeek: DailyStats
    let thisMonth: DailyStats
    let total: DailyStats
    let currentStreak: Int

    static var empty: AggregatedStats {
        AggregatedStats(
            today: DailyStats(),
            thisWeek: DailyStats(),
            thisMonth: DailyStats(),
            total: DailyStats(),
            currentStreak: 0
        )
    }
}
