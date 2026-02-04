import CloudKit
import Foundation
import SwiftData

// MARK: - SavedPrompt + Syncable

extension SavedPrompt {
    static var ckRecordType: String { "Prompt" }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(syncID: id, recordType: Self.ckRecordType, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        record.setUUID("id", id)
        record.setString("text", text)
        record.setString("projectPath", projectPath)
        record.setDate("createdAt", createdAt)
        record.setBool("wasExecuted", wasExecuted)
        record.setString("sourceFile", sourceFile)

        return record
    }

    func update(from record: CKRecord) {
        if let newText = record.string(for: "text") {
            self.text = newText
        }
        if let newProjectPath = record.string(for: "projectPath") {
            self.projectPath = newProjectPath
        }
        if let newCreatedAt = record.date(for: "createdAt") {
            self.createdAt = newCreatedAt
        }
        self.wasExecuted = record.bool(for: "wasExecuted")
        self.sourceFile = record.string(for: "sourceFile")
    }

    static func from(record: CKRecord) -> SavedPrompt? {
        guard let text = record.string(for: "text") else { return nil }

        let prompt = SavedPrompt(
            text: text,
            projectPath: record.string(for: "projectPath"),
            wasExecuted: record.bool(for: "wasExecuted")
        )

        if let id = record.uuid(for: "id") {
            // Note: SwiftData id is let, so we'd need a different init
        }

        if let createdAt = record.date(for: "createdAt") {
            prompt.createdAt = createdAt
        }

        prompt.sourceFile = record.string(for: "sourceFile")

        return prompt
    }
}

// MARK: - SavedDiff + Syncable

extension SavedDiff {
    static var ckRecordType: String { "Diff" }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(syncID: id, recordType: Self.ckRecordType, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        record.setUUID("id", id)
        record.setString("projectPath", projectPath)
        record.setString("commitHash", commitHash)
        record.setString("diffText", diffText)
        record.setInt("filesChanged", filesChanged)
        record.setInt("linesAdded", linesAdded)
        record.setInt("linesRemoved", linesRemoved)
        record.setDate("createdAt", createdAt)
        if let promptId {
            record.setUUID("promptId", promptId)
        }
        record.setString("sourceFile", sourceFile)

        return record
    }

    func update(from record: CKRecord) {
        if let newProjectPath = record.string(for: "projectPath") {
            self.projectPath = newProjectPath
        }
        self.commitHash = record.string(for: "commitHash")
        if let newDiffText = record.string(for: "diffText") {
            self.diffText = newDiffText
        }
        if let filesChanged = record.int(for: "filesChanged") {
            self.filesChanged = filesChanged
        }
        if let linesAdded = record.int(for: "linesAdded") {
            self.linesAdded = linesAdded
        }
        if let linesRemoved = record.int(for: "linesRemoved") {
            self.linesRemoved = linesRemoved
        }
        if let createdAt = record.date(for: "createdAt") {
            self.createdAt = createdAt
        }
        self.promptId = record.uuid(for: "promptId")
        self.sourceFile = record.string(for: "sourceFile")
    }
}

// MARK: - AISessionV2 + Syncable

extension AISessionV2 {
    static var ckRecordType: String { "AISession" }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(syncID: id, recordType: Self.ckRecordType, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        record.setUUID("id", id)
        record.setString("providerType", providerType)
        record.setString("modelRaw", modelRaw)
        record.setString("thinkingLevelRaw", thinkingLevelRaw)
        record.setString("projectPath", projectPath)
        record.setDate("startTime", startTime)
        record.setDate("endTime", endTime)
        record.setInt("inputTokens", inputTokens)
        record.setInt("outputTokens", outputTokens)
        record.setInt("thinkingTokens", thinkingTokens)
        record.setInt("cacheReadTokens", cacheReadTokens)
        record.setInt("cacheWriteTokens", cacheWriteTokens)
        record.setDouble("costUSD", costUSD)
        record.setBool("wasSuccessful", wasSuccessful)
        record.setString("errorMessage", errorMessage)

        return record
    }

    func update(from record: CKRecord) {
        if let providerType = record.string(for: "providerType") {
            self.providerType = providerType
        }
        if let modelRaw = record.string(for: "modelRaw") {
            self.modelRaw = modelRaw
        }
        self.thinkingLevelRaw = record.string(for: "thinkingLevelRaw")
        self.projectPath = record.string(for: "projectPath")
        if let startTime = record.date(for: "startTime") {
            self.startTime = startTime
        }
        self.endTime = record.date(for: "endTime")
        if let inputTokens = record.int(for: "inputTokens") {
            self.inputTokens = inputTokens
        }
        if let outputTokens = record.int(for: "outputTokens") {
            self.outputTokens = outputTokens
        }
        if let thinkingTokens = record.int(for: "thinkingTokens") {
            self.thinkingTokens = thinkingTokens
        }
        if let cacheReadTokens = record.int(for: "cacheReadTokens") {
            self.cacheReadTokens = cacheReadTokens
        }
        if let cacheWriteTokens = record.int(for: "cacheWriteTokens") {
            self.cacheWriteTokens = cacheWriteTokens
        }
        if let costUSD = record.double(for: "costUSD") {
            self.costUSD = costUSD
        }
        self.wasSuccessful = record.bool(for: "wasSuccessful")
        self.errorMessage = record.string(for: "errorMessage")
    }
}

// MARK: - TimeEntry + Syncable

extension TimeEntry {
    static var ckRecordType: String { "TimeEntry" }

    func toCKRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(syncID: id, recordType: Self.ckRecordType, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        record.setUUID("id", id)
        record.setString("projectPath", projectPath)
        record.setDate("startTime", startTime)
        record.setDate("endTime", endTime)
        record.setDouble("duration", duration)
        record.setBool("isManual", isManual)
        record.setString("notes", notes)
        record.setString("sessionType", sessionType)
        record.setString("aiModel", aiModel)
        if let tokensUsed {
            record.setInt("tokensUsed", tokensUsed)
        }

        return record
    }

    func update(from record: CKRecord) {
        if let projectPath = record.string(for: "projectPath") {
            self.projectPath = projectPath
        }
        if let startTime = record.date(for: "startTime") {
            self.startTime = startTime
        }
        if let endTime = record.date(for: "endTime") {
            self.endTime = endTime
        }
        if let duration = record.double(for: "duration") {
            self.duration = duration
        }
        self.isManual = record.bool(for: "isManual")
        self.notes = record.string(for: "notes")
        if let sessionType = record.string(for: "sessionType") {
            self.sessionType = sessionType
        }
        self.aiModel = record.string(for: "aiModel")
        self.tokensUsed = record.int(for: "tokensUsed")
    }
}
