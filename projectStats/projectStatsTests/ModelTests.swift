import XCTest
@testable import projectStats

/// Tests for @Model classes and data structures
final class ModelTests: XCTestCase {

    // MARK: - Project Model Tests

    func testProjectInitializesWithDefaults() {
        let project = Project(
            name: "TestProject",
            path: "/path/to/project",
            language: "Swift"
        )

        XCTAssertEqual(project.name, "TestProject")
        XCTAssertEqual(project.path, "/path/to/project")
        XCTAssertEqual(project.language, "Swift")
        XCTAssertEqual(project.status, .active)
    }

    func testProjectStatusValues() {
        XCTAssertEqual(ProjectStatus.active.rawValue, "active")
        XCTAssertEqual(ProjectStatus.archived.rawValue, "archived")
        XCTAssertEqual(ProjectStatus.paused.rawValue, "paused")
    }

    // MARK: - AIProvider Model Tests

    func testAIProviderTypeDisplayNames() {
        XCTAssertEqual(AIProviderType.claudeCode.displayName, "Claude Code")
        XCTAssertEqual(AIProviderType.anthropic.displayName, "Anthropic API")
        XCTAssertEqual(AIProviderType.openAI.displayName, "OpenAI")
        XCTAssertEqual(AIProviderType.ollama.displayName, "Ollama")
    }

    func testAIModelPricing() {
        // Test that pricing is non-negative
        for model in AIModel.allCases {
            XCTAssertGreaterThanOrEqual(model.inputPricePer1M, 0)
            XCTAssertGreaterThanOrEqual(model.outputPricePer1M, 0)
        }
    }

    func testAIModelCalculateCost() {
        let model = AIModel.claudeSonnet4
        let cost = model.calculateCost(inputTokens: 1_000_000, outputTokens: 1_000_000)

        // Should be input + output pricing
        let expectedCost = model.inputPricePer1M + model.outputPricePer1M
        XCTAssertEqual(cost, expectedCost, accuracy: 0.0001)
    }

    func testThinkingLevelBudgetTokens() {
        XCTAssertNil(ThinkingLevel.none.budgetTokens)
        XCTAssertEqual(ThinkingLevel.low.budgetTokens, 5000)
        XCTAssertEqual(ThinkingLevel.medium.budgetTokens, 10000)
        XCTAssertEqual(ThinkingLevel.high.budgetTokens, 25000)
        XCTAssertEqual(ThinkingLevel.max.budgetTokens, 128000)
    }

    // MARK: - Achievement Model Tests

    func testAchievementRarityColors() {
        // Verify all rarities have colors
        for rarity in AchievementRarity.allCases {
            XCTAssertFalse(rarity.color.description.isEmpty)
        }
    }

    func testAchievementProperties() {
        // Test a few key achievements
        let firstBlood = Achievement.firstBlood
        XCTAssertFalse(firstBlood.name.isEmpty)
        XCTAssertFalse(firstBlood.description.isEmpty)
        XCTAssertFalse(firstBlood.icon.isEmpty)
    }

    func testAchievementUnlockInitialization() {
        let unlock = AchievementUnlock(achievement: .firstBlood, projectPath: "/test/path")

        XCTAssertEqual(unlock.achievement, .firstBlood)
        XCTAssertEqual(unlock.projectPath, "/test/path")
        XCTAssertNotNil(unlock.unlockedAt)
    }

    // MARK: - TimeEntry Model Tests

    func testTimeEntryDurationCalculation() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour later

        let entry = TimeEntry(
            projectPath: "/test/project",
            startTime: startTime,
            endTime: endTime,
            sessionType: "human"
        )

        XCTAssertEqual(entry.duration, 3600, accuracy: 1.0)
    }

    // MARK: - AISessionV2 Model Tests

    func testAISessionV2CostCalculation() {
        let session = AISessionV2(
            providerType: .claudeCode,
            model: .claudeSonnet4,
            thinkingLevel: .none,
            projectPath: "/test/project"
        )

        session.end(
            inputTokens: 1000,
            outputTokens: 500,
            thinkingTokens: 0,
            cacheReadTokens: 0,
            cacheWriteTokens: 0,
            wasSuccessful: true,
            errorMessage: nil
        )

        XCTAssertEqual(session.inputTokens, 1000)
        XCTAssertEqual(session.outputTokens, 500)
        XCTAssertEqual(session.totalTokens, 1500)
        XCTAssertGreaterThanOrEqual(session.costUSD, 0)
    }

    // MARK: - Commit Model Tests

    func testCommitInitialization() {
        let date = Date()
        let commit = Commit(
            hash: "abc123def456",
            shortHash: "abc123",
            message: "Test commit",
            author: "Test Author",
            date: date,
            filesChanged: 5,
            insertions: 100,
            deletions: 50
        )

        XCTAssertEqual(commit.hash, "abc123def456")
        XCTAssertEqual(commit.shortHash, "abc123")
        XCTAssertEqual(commit.message, "Test commit")
        XCTAssertEqual(commit.author, "Test Author")
        XCTAssertEqual(commit.date, date)
        XCTAssertEqual(commit.filesChanged, 5)
        XCTAssertEqual(commit.insertions, 100)
        XCTAssertEqual(commit.deletions, 50)
    }

    // MARK: - GitRepoInfo Model Tests

    func testGitRepoInfoDefaults() {
        let info = GitRepoInfo(
            branch: "main",
            remoteURL: "https://github.com/user/repo.git",
            hasUncommittedChanges: false,
            aheadCount: 0,
            behindCount: 0
        )

        XCTAssertEqual(info.branch, "main")
        XCTAssertEqual(info.remoteURL, "https://github.com/user/repo.git")
        XCTAssertFalse(info.hasUncommittedChanges)
        XCTAssertEqual(info.aheadCount, 0)
        XCTAssertEqual(info.behindCount, 0)
    }

    // MARK: - SecretMatch Model Tests

    func testSecretMatchSeverity() {
        let highSecret = SecretMatch(
            type: "API Key",
            value: "sk-test123",
            file: "config.swift",
            line: 10,
            severity: .high
        )

        let mediumSecret = SecretMatch(
            type: "Password",
            value: "password123",
            file: "config.swift",
            line: 20,
            severity: .medium
        )

        XCTAssertEqual(highSecret.severity, .high)
        XCTAssertEqual(mediumSecret.severity, .medium)
    }

    // MARK: - EnvironmentVariable Model Tests

    func testEnvironmentVariableSourceTypes() {
        XCTAssertEqual(VariableSource.envFile.rawValue, "envFile")
        XCTAssertEqual(VariableSource.system.rawValue, "system")
        XCTAssertEqual(VariableSource.custom.rawValue, "custom")
    }

    // MARK: - DBv2 Models Tests

    func testWorkItemInitialization() {
        let item = WorkItem(
            title: "Test Task",
            projectPath: "/test/project"
        )

        XCTAssertEqual(item.title, "Test Task")
        XCTAssertEqual(item.projectPath, "/test/project")
        XCTAssertFalse(item.isCompleted)
    }

    func testWeeklyGoalInitialization() {
        let goal = WeeklyGoal(
            title: "Complete feature",
            weekStart: Date()
        )

        XCTAssertEqual(goal.title, "Complete feature")
        XCTAssertFalse(goal.isCompleted)
    }
}
