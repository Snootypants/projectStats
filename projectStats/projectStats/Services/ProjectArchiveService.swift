import Foundation
import SwiftData

@MainActor
final class ProjectArchiveService {
    static let shared = ProjectArchiveService()

    private init() {}

    func archiveProject(_ path: String, context: ModelContext) {
        let descriptor = FetchDescriptor<CachedProject>(
            predicate: #Predicate { $0.path == path }
        )
        guard let project = try? context.fetch(descriptor).first else { return }

        project.isArchived = true
        project.archivedAt = Date()
        try? context.save()
    }

    func restoreProject(_ path: String, context: ModelContext) {
        let descriptor = FetchDescriptor<CachedProject>(
            predicate: #Predicate { $0.path == path }
        )
        guard let project = try? context.fetch(descriptor).first else { return }

        project.isArchived = false
        project.archivedAt = nil
        try? context.save()
    }

    func getArchivedProjects(context: ModelContext) -> [CachedProject] {
        let descriptor = FetchDescriptor<CachedProject>(
            predicate: #Predicate { $0.isArchived == true }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func getActiveProjects(context: ModelContext) -> [CachedProject] {
        let descriptor = FetchDescriptor<CachedProject>(
            predicate: #Predicate { $0.isArchived == false }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
