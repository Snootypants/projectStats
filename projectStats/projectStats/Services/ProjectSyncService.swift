import Foundation
import SwiftData
import CryptoKit
import os.log

@MainActor
final class ProjectSyncService {
    static let shared = ProjectSyncService()
    private init() {}

    // MARK: - Full Sync

    func syncToSwiftData(projects: [Project], perProjectActivities: [String: [Date: ActivityStats]]) async {
        let context = AppModelContainer.shared.mainContext

        do {
            let existingDescriptor = FetchDescriptor<CachedProject>()
            let existingCached = try context.fetch(existingDescriptor)
            let existingByPath = Dictionary(uniqueKeysWithValues: existingCached.map { ($0.path, $0) })

            for project in projects {
                if let cached = existingByPath[project.path.path] {
                    cached.update(from: project)
                } else {
                    let newCached = CachedProject(
                        path: project.path.path,
                        name: project.name,
                        descriptionText: project.description,
                        githubURL: project.githubURL,
                        language: project.language,
                        lineCount: project.lineCount,
                        fileCount: project.fileCount,
                        promptCount: project.promptCount,
                        workLogCount: project.workLogCount,
                        lastCommitHash: project.lastCommit?.id,
                        lastCommitMessage: project.lastCommit?.message,
                        lastCommitAuthor: project.lastCommit?.author,
                        lastCommitDate: project.lastCommit?.date,
                        lastScanned: project.lastScanned,
                        jsonStatus: project.jsonStatus,
                        techStack: project.techStack,
                        languageBreakdown: project.languageBreakdown,
                        structure: project.structure,
                        structureNotes: project.structureNotes,
                        sourceDirectories: project.sourceDirectories,
                        excludedDirectories: project.excludedDirectories,
                        firstCommitDate: project.firstCommitDate,
                        totalCommits: project.totalCommits,
                        branches: project.branches,
                        currentBranch: project.currentBranch,
                        statsGeneratedAt: project.statsGeneratedAt,
                        statsSource: project.statsSource
                    )
                    context.insert(newCached)
                }
            }

            let currentPaths = Set(projects.map { $0.path.path })
            for cached in existingCached {
                if !currentPaths.contains(cached.path) &&
                   !FileManager.default.fileExists(atPath: cached.path) {
                    context.delete(cached)
                }
            }

            context.safeSave()
            Log.data.info("[ProjectSync] Synced \(projects.count) projects to SwiftData")
        } catch {
            Log.data.error("[ProjectSync] Error syncing projects: \(error)")
        }

        // Sync activities
        do {
            let activityDescriptor = FetchDescriptor<CachedDailyActivity>()
            let existingActivities = try context.fetch(activityDescriptor)
            for activity in existingActivities {
                context.delete(activity)
            }

            for (projectPath, activities) in perProjectActivities {
                for (date, stats) in activities {
                    let cached = CachedDailyActivity(
                        date: date,
                        projectPath: projectPath,
                        linesAdded: stats.linesAdded,
                        linesRemoved: stats.linesRemoved,
                        commits: stats.commits
                    )
                    context.insert(cached)
                }
            }

            context.safeSave()
            Log.data.info("[ProjectSync] Synced \(perProjectActivities.count) projects' activities")
        } catch {
            Log.data.error("[ProjectSync] Error syncing activities: \(error)")
        }

        await syncPromptsToSwiftData(projects: projects, context: context)
        await syncWorkLogsToSwiftData(projects: projects, context: context)
    }

    // MARK: - Single Project Sync

    func syncSingleProject(path: String, projects: [Project]) async -> Project? {
        guard let project = projects.first(where: { $0.path.path == path }) else { return nil }

        let context = AppModelContainer.shared.mainContext

        await syncPrompts(for: project, context: context)
        await syncWorkLogs(for: project, context: context)
        await syncRecentCommits(for: project, context: context)
        await syncProjectStats(for: project, context: context)

        context.safeSave()

        if let updatedCached = try? context.fetch(FetchDescriptor<CachedProject>(
            predicate: #Predicate { $0.path == path }
        )).first {
            return updatedCached.toProject()
        }
        return nil
    }

    // MARK: - Cache Reload

    func reloadFromCache() async -> (projects: [Project], activities: [Date: ActivityStats]) {
        let context = AppModelContainer.shared.mainContext
        var loadedProjects: [Project] = []
        var allActivities: [Date: ActivityStats] = [:]

        do {
            let descriptor = FetchDescriptor<CachedProject>(
                sortBy: [SortDescriptor(\.lastCommitDate, order: .reverse)]
            )
            loadedProjects = try context.fetch(descriptor).map { $0.toProject() }
        } catch {
            Log.data.error("[ProjectSync] Error loading projects from cache: \(error)")
        }

        do {
            let activityDescriptor = FetchDescriptor<CachedDailyActivity>()
            let cachedActivities = try context.fetch(activityDescriptor)

            for cached in cachedActivities {
                let date = cached.date.startOfDay
                if var existing = allActivities[date] {
                    existing.linesAdded += cached.linesAdded
                    existing.linesRemoved += cached.linesRemoved
                    existing.commits += cached.commits
                    allActivities[date] = existing
                } else {
                    allActivities[date] = ActivityStats(
                        date: date,
                        linesAdded: cached.linesAdded,
                        linesRemoved: cached.linesRemoved,
                        commits: cached.commits
                    )
                }
            }
        } catch {
            Log.data.error("[ProjectSync] Error loading activities from cache: \(error)")
        }

        return (loadedProjects, allActivities)
    }

    // MARK: - File Counting

    func countPromptFiles(for projects: [Project]) -> Int {
        let fm = FileManager.default
        var count = 0
        for project in projects {
            let promptsDir = project.path.appendingPathComponent("prompts")
            guard fm.fileExists(atPath: promptsDir.path) else { continue }
            guard let files = try? fm.contentsOfDirectory(at: promptsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            count += files.filter { $0.pathExtension == "md" }.count
        }
        return count
    }

    func countWorkLogFiles(for projects: [Project]) -> Int {
        let fm = FileManager.default
        var count = 0
        for project in projects {
            let workDir = project.path.appendingPathComponent("work")
            guard fm.fileExists(atPath: workDir.path) else { continue }
            if let files = try? fm.contentsOfDirectory(at: workDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                count += files.filter { $0.pathExtension == "md" }.count
            }
            let statsDir = workDir.appendingPathComponent("stats")
            if fm.fileExists(atPath: statsDir.path),
               let statFiles = try? fm.contentsOfDirectory(at: statsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                count += statFiles.filter { $0.pathExtension == "md" }.count
            }
        }
        return count
    }

    // MARK: - Prompts

    private func syncPromptsToSwiftData(projects: [Project], context: ModelContext) async {
        let fm = FileManager.default

        do {
            let existingDescriptor = FetchDescriptor<CachedPrompt>()
            let existingCached = try context.fetch(existingDescriptor)
            let existingByKey = Dictionary(
                uniqueKeysWithValues: existingCached.map { ("\($0.projectPath)::\($0.filename)", $0) }
            )

            var seenKeys: Set<String> = []

            for project in projects {
                let promptsDir = project.path.appendingPathComponent("prompts")
                guard fm.fileExists(atPath: promptsDir.path) else { continue }

                guard let files = try? fm.contentsOfDirectory(
                    at: promptsDir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                let mdFiles = files.filter { $0.pathExtension == "md" }

                for fileURL in mdFiles {
                    let filename = fileURL.lastPathComponent
                    let key = "\(project.path.path)::\(filename)"
                    seenKeys.insert(key)

                    let baseName = fileURL.deletingPathExtension().lastPathComponent
                    let promptNumber = Int(baseName.filter { $0.isNumber }) ?? 0

                    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                    let hash = content.sha256Hash

                    let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
                    let fileModified = (attrs?[.modificationDate] as? Date) ?? Date()

                    if let existing = existingByKey[key], existing.contentHash == hash {
                        continue
                    }

                    if let existing = existingByKey[key] {
                        existing.content = content
                        existing.contentHash = hash
                        existing.promptNumber = promptNumber
                        existing.fileModified = fileModified
                        existing.cachedAt = Date()
                    } else {
                        let cached = CachedPrompt(
                            projectPath: project.path.path,
                            promptNumber: promptNumber,
                            filename: filename,
                            content: content,
                            contentHash: hash,
                            fileModified: fileModified
                        )
                        context.insert(cached)
                    }
                }
            }

            for cached in existingCached {
                let key = "\(cached.projectPath)::\(cached.filename)"
                if !seenKeys.contains(key) {
                    context.delete(cached)
                }
            }

            context.safeSave()
            Log.sync.info("[ProjectSync] Synced prompts to SwiftData")
        } catch {
            Log.sync.error("[ProjectSync] Error syncing prompts: \(error)")
        }
    }

    func syncPrompts(for project: Project, context: ModelContext) async {
        let fm = FileManager.default
        let promptsDir = project.path.appendingPathComponent("prompts")
        guard fm.fileExists(atPath: promptsDir.path) else { return }

        let projectPath = project.path.path
        do {
            let existingDescriptor = FetchDescriptor<CachedPrompt>(
                predicate: #Predicate { $0.projectPath == projectPath }
            )
            let existingCached = try context.fetch(existingDescriptor)
            let existingByFilename = Dictionary(uniqueKeysWithValues: existingCached.map { ($0.filename, $0) })

            var seen: Set<String> = []

            guard let files = try? fm.contentsOfDirectory(
                at: promptsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            let mdFiles = files.filter { $0.pathExtension == "md" }

            for fileURL in mdFiles {
                let filename = fileURL.lastPathComponent
                seen.insert(filename)

                let baseName = fileURL.deletingPathExtension().lastPathComponent
                let promptNumber = Int(baseName.filter { $0.isNumber }) ?? 0

                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let hash = content.sha256Hash

                let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
                let fileModified = (attrs?[.modificationDate] as? Date) ?? Date()

                if let existing = existingByFilename[filename], existing.contentHash == hash {
                    continue
                }

                if let existing = existingByFilename[filename] {
                    existing.content = content
                    existing.contentHash = hash
                    existing.promptNumber = promptNumber
                    existing.fileModified = fileModified
                    existing.cachedAt = Date()
                } else {
                    let cached = CachedPrompt(
                        projectPath: projectPath,
                        promptNumber: promptNumber,
                        filename: filename,
                        content: content,
                        contentHash: hash,
                        fileModified: fileModified
                    )
                    context.insert(cached)
                }
            }

            for cached in existingCached where !seen.contains(cached.filename) {
                context.delete(cached)
            }
        } catch {
            Log.sync.error("[ProjectSync] Error syncing prompts for project: \(error)")
        }
    }

    // MARK: - Work Logs

    private func syncWorkLogsToSwiftData(projects: [Project], context: ModelContext) async {
        let fm = FileManager.default

        do {
            let existingDescriptor = FetchDescriptor<CachedWorkLog>()
            let existingCached = try context.fetch(existingDescriptor)
            let existingByKey = Dictionary(
                uniqueKeysWithValues: existingCached.map { ("\($0.projectPath)::\($0.filename)::\($0.isStatsFile)", $0) }
            )

            var seenKeys: Set<String> = []

            for project in projects {
                let workDir = project.path.appendingPathComponent("work")
                guard fm.fileExists(atPath: workDir.path) else { continue }

                syncWorkLogFiles(
                    in: workDir,
                    projectPath: project.path.path,
                    isStats: false,
                    existingByKey: existingByKey,
                    seenKeys: &seenKeys,
                    context: context
                )

                let statsDir = workDir.appendingPathComponent("stats")
                if fm.fileExists(atPath: statsDir.path) {
                    syncWorkLogFiles(
                        in: statsDir,
                        projectPath: project.path.path,
                        isStats: true,
                        existingByKey: existingByKey,
                        seenKeys: &seenKeys,
                        context: context
                    )
                }
            }

            for cached in existingCached {
                let key = "\(cached.projectPath)::\(cached.filename)::\(cached.isStatsFile)"
                if !seenKeys.contains(key) {
                    context.delete(cached)
                }
            }

            context.safeSave()
            Log.sync.info("[ProjectSync] Synced work logs to SwiftData")
        } catch {
            Log.sync.error("[ProjectSync] Error syncing work logs: \(error)")
        }
    }

    func syncWorkLogs(for project: Project, context: ModelContext) async {
        let fm = FileManager.default
        let workDir = project.path.appendingPathComponent("work")
        guard fm.fileExists(atPath: workDir.path) else { return }

        let projectPath = project.path.path
        do {
            let existingDescriptor = FetchDescriptor<CachedWorkLog>(
                predicate: #Predicate { $0.projectPath == projectPath }
            )
            let existingCached = try context.fetch(existingDescriptor)
            let existingByKey = Dictionary(
                uniqueKeysWithValues: existingCached.map { ("\($0.filename)::\($0.isStatsFile)", $0) }
            )

            var seenKeys: Set<String> = []

            syncWorkLogFiles(
                in: workDir,
                projectPath: project.path.path,
                isStats: false,
                existingByKey: existingByKey,
                seenKeys: &seenKeys,
                context: context
            )

            let statsDir = workDir.appendingPathComponent("stats")
            if fm.fileExists(atPath: statsDir.path) {
                syncWorkLogFiles(
                    in: statsDir,
                    projectPath: project.path.path,
                    isStats: true,
                    existingByKey: existingByKey,
                    seenKeys: &seenKeys,
                    context: context
                )
            }

            for cached in existingCached {
                let key = "\(cached.filename)::\(cached.isStatsFile)"
                if !seenKeys.contains(key) {
                    context.delete(cached)
                }
            }
        } catch {
            Log.sync.error("[ProjectSync] Error syncing work logs for project: \(error)")
        }
    }

    // MARK: - Commits

    func syncRecentCommits(for project: Project, context: ModelContext) async {
        let gitDir = project.path.appendingPathComponent(".git")
        guard FileManager.default.fileExists(atPath: gitDir.path) else { return }

        let projectPath = project.path.path
        let format = "%H%x1f%h%x1f%s%x1f%an%x1f%ae%x1f%aI"
        let command = "cd '\(projectPath)' && git log --pretty=format:'\(format)' --numstat -50"
        let result = Shell.runResult(command)
        guard result.exitCode == 0, !result.output.isEmpty else { return }

        let commits = parseGitLogOutput(result.output, projectPath: projectPath)
        if commits.isEmpty { return }

        do {
            let existingDescriptor = FetchDescriptor<CachedCommit>(
                predicate: #Predicate { $0.projectPath == projectPath }
            )
            let existing = try context.fetch(existingDescriptor)
            let existingIds = Set(existing.map { $0.commitHash ?? $0.shortHash })

            for commit in commits {
                let commitId = commit.commitHash ?? commit.shortHash
                if existingIds.contains(commitId) { continue }
                context.insert(commit)
            }
        } catch {
            Log.sync.error("[ProjectSync] Error syncing recent commits: \(error)")
        }
    }

    // MARK: - Project Stats

    func syncProjectStats(for project: Project, context: ModelContext) async {
        do {
            let projectPath = project.path.path
            let projectDescriptor = FetchDescriptor<CachedProject>(
                predicate: #Predicate { $0.path == projectPath }
            )
            guard let cached = try context.fetch(projectDescriptor).first else { return }

            let promptDescriptor = FetchDescriptor<CachedPrompt>(
                predicate: #Predicate { $0.projectPath == projectPath }
            )
            cached.promptCount = (try? context.fetchCount(promptDescriptor)) ?? 0

            let workLogDescriptor = FetchDescriptor<CachedWorkLog>(
                predicate: #Predicate { $0.projectPath == projectPath && $0.isStatsFile == false }
            )
            cached.workLogCount = (try? context.fetchCount(workLogDescriptor)) ?? 0

            let commitDescriptor = FetchDescriptor<CachedCommit>(
                predicate: #Predicate { $0.projectPath == projectPath },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            if let latestCommit = try? context.fetch(commitDescriptor).first {
                cached.lastCommitHash = latestCommit.shortHash
                cached.lastCommitMessage = latestCommit.message
                cached.lastCommitAuthor = latestCommit.author
                cached.lastCommitDate = latestCommit.date
            }

            let (freshLines, freshFiles) = LineCounter.countLines(in: project.path)
            cached.lineCount = freshLines
            cached.fileCount = freshFiles

            cached.lastScanned = Date()
        } catch {
            Log.sync.error("[ProjectSync] Error syncing project stats: \(error)")
        }
    }

    // MARK: - Private Helpers

    private func parseGitLogOutput(_ output: String, projectPath: String) -> [CachedCommit] {
        var commits: [CachedCommit] = []
        var current: (hash: String, shortHash: String, message: String, author: String, email: String, date: Date)?
        var linesAdded = 0
        var linesDeleted = 0
        var filesChanged = 0

        let lines = output.components(separatedBy: .newlines)
        let dateFormatter = ISO8601DateFormatter()

        for line in lines {
            if line.contains("\u{1f}") {
                if let current = current {
                    commits.append(CachedCommit(
                        projectPath: projectPath,
                        commitHash: current.hash,
                        shortHash: current.shortHash,
                        message: current.message,
                        author: current.author,
                        authorEmail: current.email,
                        date: current.date,
                        linesAdded: linesAdded,
                        linesDeleted: linesDeleted,
                        filesChanged: filesChanged
                    ))
                }

                let parts = line.components(separatedBy: "\u{1f}")
                if parts.count >= 6 {
                    current = (
                        hash: parts[0],
                        shortHash: parts[1],
                        message: parts[2],
                        author: parts[3],
                        email: parts[4],
                        date: dateFormatter.date(from: parts[5]) ?? Date()
                    )
                } else {
                    current = nil
                }

                linesAdded = 0
                linesDeleted = 0
                filesChanged = 0
            } else if !line.isEmpty {
                let parts = line.components(separatedBy: "\t")
                if parts.count >= 2 {
                    linesAdded += Int(parts[0]) ?? 0
                    linesDeleted += Int(parts[1]) ?? 0
                    filesChanged += 1
                }
            }
        }

        if let current = current {
            commits.append(CachedCommit(
                projectPath: projectPath,
                commitHash: current.hash,
                shortHash: current.shortHash,
                message: current.message,
                author: current.author,
                authorEmail: current.email,
                date: current.date,
                linesAdded: linesAdded,
                linesDeleted: linesDeleted,
                filesChanged: filesChanged
            ))
        }

        return commits
    }

    private func syncWorkLogFiles(
        in directory: URL,
        projectPath: String,
        isStats: Bool,
        existingByKey: [String: CachedWorkLog],
        seenKeys: inout Set<String>,
        context: ModelContext
    ) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let mdFiles = files.filter { $0.pathExtension == "md" }

        for fileURL in mdFiles {
            let filename = fileURL.lastPathComponent
            let key = "\(projectPath)::\(filename)::\(isStats)"
            seenKeys.insert(key)

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let hash = content.sha256Hash

            let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
            let fileModified = (attrs?[.modificationDate] as? Date) ?? Date()

            if let existing = existingByKey[key], existing.contentHash == hash {
                continue
            }

            var started: Date? = nil
            var ended: Date? = nil
            var parsedLinesAdded: Int? = nil
            var parsedLinesDeleted: Int? = nil
            var commitHash: String? = nil
            var summary: String? = nil

            if isStats {
                let parsed = parseStatsFile(content)
                started = parsed.started
                ended = parsed.ended
                parsedLinesAdded = parsed.linesAdded
                parsedLinesDeleted = parsed.linesDeleted
                commitHash = parsed.commitHash
                summary = parsed.summary
            }

            if let existing = existingByKey[key] {
                existing.content = content
                existing.contentHash = hash
                existing.fileModified = fileModified
                existing.cachedAt = Date()
                existing.started = started
                existing.ended = ended
                existing.linesAdded = parsedLinesAdded
                existing.linesDeleted = parsedLinesDeleted
                existing.commitHash = commitHash
                existing.summary = summary
            } else {
                let cached = CachedWorkLog(
                    projectPath: projectPath,
                    filename: filename,
                    content: content,
                    contentHash: hash,
                    fileModified: fileModified,
                    isStatsFile: isStats,
                    started: started,
                    ended: ended,
                    linesAdded: parsedLinesAdded,
                    linesDeleted: parsedLinesDeleted,
                    commitHash: commitHash,
                    summary: summary
                )
                context.insert(cached)
            }
        }
    }

    private func parseStatsFile(_ content: String) -> (
        started: Date?, ended: Date?, linesAdded: Int?,
        linesDeleted: Int?, commitHash: String?, summary: String?
    ) {
        let lines = content.components(separatedBy: .newlines)
        var started: Date? = nil
        var ended: Date? = nil
        var linesAdded: Int? = nil
        var linesDeleted: Int? = nil
        var commitHash: String? = nil
        var summaryLines: [String] = []
        var pastHeader = false

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]

        let simpleDateFormatter = DateFormatter()
        simpleDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !pastHeader {
                if trimmed.isEmpty && (started != nil || commitHash != nil) {
                    pastHeader = true
                    continue
                }

                if trimmed.hasPrefix("started:") {
                    let value = trimmed.replacingOccurrences(of: "started:", with: "").trimmingCharacters(in: .whitespaces)
                    started = dateFormatter.date(from: value) ?? simpleDateFormatter.date(from: value)
                } else if trimmed.hasPrefix("ended:") {
                    let value = trimmed.replacingOccurrences(of: "ended:", with: "").trimmingCharacters(in: .whitespaces)
                    ended = dateFormatter.date(from: value) ?? simpleDateFormatter.date(from: value)
                } else if trimmed.hasPrefix("lines_added:") {
                    let value = trimmed.replacingOccurrences(of: "lines_added:", with: "").trimmingCharacters(in: .whitespaces)
                    linesAdded = Int(value)
                } else if trimmed.hasPrefix("lines_deleted:") {
                    let value = trimmed.replacingOccurrences(of: "lines_deleted:", with: "").trimmingCharacters(in: .whitespaces)
                    linesDeleted = Int(value)
                } else if trimmed.hasPrefix("commit:") {
                    commitHash = trimmed.replacingOccurrences(of: "commit:", with: "").trimmingCharacters(in: .whitespaces)
                }
            } else {
                summaryLines.append(line)
            }
        }

        let summary = summaryLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return (started, ended, linesAdded, linesDeleted, commitHash, summary.isEmpty ? nil : summary)
    }
}
