import Foundation
import SwiftData
import os.log

/// Handles migration to DB v2 models
@MainActor
final class DBv2MigrationService {
    static let shared = DBv2MigrationService()

    private init() {}

    var hasMigrated: Bool {
        SchemaVersion.dbv2Completed
    }

    func migrateIfNeeded(context: ModelContext) async {
        guard !hasMigrated else { return }

        Log.data.info("[DBv2Migration] Starting migration...")

        await migrateCommitsToDailyMetrics(context: context)
        await migrateTimeEntriesToSessions(context: context)

        SchemaVersion.dbv2Completed = true
        Log.data.info("[DBv2Migration] Migration completed")
    }

    /// Aggregate commits into DailyMetric records
    private func migrateCommitsToDailyMetrics(context: ModelContext) async {
        let descriptor = FetchDescriptor<CachedCommit>()
        guard let commits = try? context.fetch(descriptor) else { return }

        // Group commits by date and project
        var grouped: [String: [CachedCommit]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for commit in commits {
            let dateKey = dateFormatter.string(from: commit.date)
            let key = "\(commit.projectPath)|\(dateKey)"
            grouped[key, default: []].append(commit)
        }

        // Create DailyMetric for each group
        for (key, dayCommits) in grouped {
            let parts = key.split(separator: "|")
            guard parts.count == 2,
                  let date = dateFormatter.date(from: String(parts[1])) else { continue }

            let projectPath = String(parts[0])

            let metric = DailyMetric(
                date: date,
                projectPath: projectPath,
                totalCommits: dayCommits.count,
                totalLinesAdded: dayCommits.reduce(0) { $0 + $1.linesAdded },
                totalLinesRemoved: dayCommits.reduce(0) { $0 + $1.linesDeleted },
                uniqueFilesModified: dayCommits.reduce(0) { $0 + $1.filesChanged }
            )

            context.insert(metric)
        }

        // Also create global daily metrics
        var globalGrouped: [String: [CachedCommit]] = [:]
        for commit in commits {
            let dateKey = dateFormatter.string(from: commit.date)
            globalGrouped[dateKey, default: []].append(commit)
        }

        for (dateKey, dayCommits) in globalGrouped {
            guard let date = dateFormatter.date(from: dateKey) else { continue }

            let metric = DailyMetric(
                date: date,
                projectPath: nil,  // global
                totalCommits: dayCommits.count,
                totalLinesAdded: dayCommits.reduce(0) { $0 + $1.linesAdded },
                totalLinesRemoved: dayCommits.reduce(0) { $0 + $1.linesDeleted },
                uniqueFilesModified: dayCommits.reduce(0) { $0 + $1.filesChanged }
            )

            context.insert(metric)
        }

        context.safeSave()
        Log.data.info("[DBv2Migration] Migrated \(grouped.count) project daily metrics")
    }

    /// Convert TimeEntry records to ProjectSession records
    private func migrateTimeEntriesToSessions(context: ModelContext) async {
        let descriptor = FetchDescriptor<TimeEntry>()
        guard let entries = try? context.fetch(descriptor) else { return }

        // Group entries by project and day to create sessions
        var grouped: [String: [TimeEntry]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for entry in entries {
            let dateKey = dateFormatter.string(from: entry.startTime)
            let key = "\(entry.projectPath)|\(dateKey)"
            grouped[key, default: []].append(entry)
        }

        // Create session for each day of work
        for (key, dayEntries) in grouped {
            let parts = key.split(separator: "|")
            guard parts.count == 2 else { continue }

            let projectPath = String(parts[0])
            let sortedEntries = dayEntries.sorted { $0.startTime < $1.startTime }

            guard let firstEntry = sortedEntries.first,
                  let lastEntry = sortedEntries.last else { continue }

            let totalDuration = dayEntries.reduce(0.0) { $0 + $1.duration }

            let session = ProjectSession(
                projectPath: projectPath,
                startTime: firstEntry.startTime,
                endTime: lastEntry.endTime,
                duration: totalDuration,
                notes: dayEntries.compactMap { $0.notes }.joined(separator: "\n")
            )

            context.insert(session)
        }

        context.safeSave()
        Log.data.info("[DBv2Migration] Migrated \(grouped.count) sessions from time entries")
    }

    /// Force re-migration if needed (for development/debugging)
    func resetMigration() {
        SchemaVersion.dbv2Completed = false
    }

    /// Get migration status details
    func getMigrationStatus(context: ModelContext) -> (sessions: Int, dailyMetrics: Int, workItems: Int, goals: Int) {
        let sessions = (try? context.fetchCount(FetchDescriptor<ProjectSession>())) ?? 0
        let metrics = (try? context.fetchCount(FetchDescriptor<DailyMetric>())) ?? 0
        let items = (try? context.fetchCount(FetchDescriptor<WorkItem>())) ?? 0
        let goals = (try? context.fetchCount(FetchDescriptor<WeeklyGoal>())) ?? 0

        return (sessions, metrics, items, goals)
    }
}
