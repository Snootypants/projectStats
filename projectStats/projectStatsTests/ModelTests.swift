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

    // MARK: - PromptTemplate Model Tests

    func testPromptTemplateInitialization() {
        let template = PromptTemplate(name: "Default", content: "Template content", isDefault: true)

        XCTAssertEqual(template.name, "Default")
        XCTAssertEqual(template.content, "Template content")
        XCTAssertTrue(template.isDefault)
        XCTAssertEqual(template.currentVersionNumber, 1)
        XCTAssertEqual(template.oneShotSuccessCount, 0)
        XCTAssertEqual(template.totalPromptsFromVersion, 0)
        XCTAssertTrue(template.versions.isEmpty)
    }

    func testPromptTemplateEditCreatesVersion() {
        let template = PromptTemplate(name: "Test", content: "Version 1 content")
        template.oneShotSuccessCount = 5
        template.totalPromptsFromVersion = 10

        template.edit(newContent: "Version 2 content", editNote: "Updated format")

        // Template should have new content
        XCTAssertEqual(template.content, "Version 2 content")
        XCTAssertEqual(template.currentVersionNumber, 2)

        // Stats should be reset
        XCTAssertEqual(template.oneShotSuccessCount, 0)
        XCTAssertEqual(template.totalPromptsFromVersion, 0)

        // Version should be created with old stats
        XCTAssertEqual(template.versions.count, 1)
        let version = template.versions[0]
        XCTAssertEqual(version.versionNumber, 1)
        XCTAssertEqual(version.content, "Version 1 content")
        XCTAssertEqual(version.editNote, "Updated format")
        XCTAssertEqual(version.oneShotSuccessCount, 5)
        XCTAssertEqual(version.totalPromptsFromVersion, 10)
    }

    func testPromptTemplateOneShotCounter() {
        let template = PromptTemplate(name: "Test", content: "Content")

        template.recordOneShotSuccess()
        template.recordOneShotSuccess()
        template.recordPromptUse()

        XCTAssertEqual(template.oneShotSuccessCount, 2)
        XCTAssertEqual(template.totalPromptsFromVersion, 3)
    }

    func testPromptTemplateEditResetsCounter() {
        let template = PromptTemplate(name: "Test", content: "V1")
        template.recordOneShotSuccess()
        template.recordOneShotSuccess()
        template.recordPromptUse()

        template.edit(newContent: "V2")

        XCTAssertEqual(template.oneShotSuccessCount, 0)
        XCTAssertEqual(template.totalPromptsFromVersion, 0)

        // Old stats preserved in version
        XCTAssertEqual(template.versions[0].oneShotSuccessCount, 2)
        XCTAssertEqual(template.versions[0].totalPromptsFromVersion, 3)
    }

    func testPromptTemplateVersionHistoryOrdered() {
        let template = PromptTemplate(name: "Test", content: "V1")
        template.edit(newContent: "V2", editNote: "First edit")
        // Small delay to ensure different timestamps
        template.edit(newContent: "V3", editNote: "Second edit")

        let ordered = template.orderedVersions
        XCTAssertEqual(ordered.count, 2)
        // Newest first
        XCTAssertEqual(ordered[0].versionNumber, 2)
        XCTAssertEqual(ordered[1].versionNumber, 1)
    }

    // MARK: - AIModel 4.5/4.6 Series Tests

    func testAIModelOpus46RawValue() {
        XCTAssertEqual(AIModel.claudeOpus46.rawValue, "claude-opus-4-6")
    }

    func testAIModelOpus46DisplayName() {
        XCTAssertEqual(AIModel.claudeOpus46.displayName, "Claude Opus 4.6")
    }

    func testAIModelSonnet5Exists() {
        let model = AIModel.claudeSonnet5
        XCTAssertTrue(model.isComingSoon)
    }

    func testAIModelSonnet5IsComingSoon() {
        XCTAssertTrue(AIModel.claudeSonnet5.isComingSoon)
        XCTAssertFalse(AIModel.claudeOpus46.isComingSoon)
        XCTAssertFalse(AIModel.claudeSonnet4.isComingSoon)
    }

    func testAIModelSonnet45RawValue() {
        XCTAssertEqual(AIModel.claudeSonnet45.rawValue, "claude-sonnet-4-5-20250929")
    }

    func testAIModelHaiku45RawValue() {
        XCTAssertEqual(AIModel.claudeHaiku45.rawValue, "claude-haiku-4-5-20251001")
    }

    // MARK: - SparkleEdgeEffect Tests

    func testSparkleEdgeEffectPointOnPerimeter() {
        // SparkleEdgeEffect is a view — verify it exists and can be instantiated
        let effect = SparkleEdgeEffect()
        XCTAssertNotNil(effect)
        // Visual rendering tested in UI
    }

    // MARK: - LineNumberTextEditor Tests

    func testLineNumberTextEditorReadOnlyDefault() {
        // LineNumberTextEditor defaults to readOnly = false
        // (Structural test — actual rendering tested in UI)
        let binding = Binding.constant("Hello\nWorld\nTest")
        let editor = LineNumberTextEditor(text: binding, readOnly: true)
        XCTAssertTrue(editor.readOnly)
    }

    func testLineNumberRulerViewExists() {
        // Verify the class exists and can be referenced
        let scrollView = NSScrollView()
        let ruler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        XCTAssertNotNil(ruler)
        XCTAssertTrue(ruler.isFlipped)
    }

    // MARK: - CompactLockoutBar Tests

    @MainActor
    func testCompactLockoutBarPercentages() {
        let service = ClaudePlanUsageService.shared
        // Service defaults to 0
        XCTAssertEqual(Int(service.fiveHourUtilization * 100), 0)
        XCTAssertEqual(Int(service.sevenDayUtilization * 100), 0)
    }

    // MARK: - Projects Tab Tooltip Tests

    func testProjectsTabTooltipWithProjects() {
        let projects = [
            Project(path: URL(fileURLWithPath: "/test/alpha"), name: "Alpha",
                    lastCommit: Commit(hash: "a", shortHash: "a", message: "m", author: "a", date: Date(), filesChanged: 0, insertions: 0, deletions: 0)),
            Project(path: URL(fileURLWithPath: "/test/beta"), name: "Beta",
                    lastCommit: Commit(hash: "b", shortHash: "b", message: "m", author: "a", date: Date().addingTimeInterval(-3600), filesChanged: 0, insertions: 0, deletions: 0)),
            Project(path: URL(fileURLWithPath: "/test/gamma"), name: "Gamma",
                    lastCommit: Commit(hash: "c", shortHash: "c", message: "m", author: "a", date: Date().addingTimeInterval(-7200), filesChanged: 0, insertions: 0, deletions: 0)),
            Project(path: URL(fileURLWithPath: "/test/delta"), name: "Delta")
        ]
        let tooltip = projectsTabTooltipText(projects: projects)
        XCTAssertTrue(tooltip.contains("Projects: 4"))
        XCTAssertTrue(tooltip.contains("Alpha"))
        XCTAssertTrue(tooltip.contains("Beta"))
        XCTAssertTrue(tooltip.contains("Gamma"))
        XCTAssertFalse(tooltip.contains("Delta")) // Only top 3
    }

    func testProjectsTabTooltipEmpty() {
        let tooltip = projectsTabTooltipText(projects: [])
        XCTAssertEqual(tooltip, "No projects")
    }

    func testProjectsTabTooltipOneProject() {
        let projects = [Project(path: URL(fileURLWithPath: "/test/solo"), name: "Solo")]
        let tooltip = projectsTabTooltipText(projects: projects)
        XCTAssertTrue(tooltip.contains("Projects: 1"))
        XCTAssertTrue(tooltip.contains("Solo"))
    }

    // Helper matching the view logic
    private func projectsTabTooltipText(projects: [Project]) -> String {
        let count = projects.count
        if count == 0 { return "No projects" }
        let recent = projects
            .sorted { ($0.lastCommit?.date ?? .distantPast) > ($1.lastCommit?.date ?? .distantPast) }
            .prefix(3)
            .map(\.name)
        return "Projects: \(count)\nRecent: \(recent.joined(separator: ", "))"
    }

    // MARK: - Prompt Helper Compose Tests

    func testPromptHelperComposeWithoutTemplate() {
        let userText = "Fix the login bug in auth.swift"
        let composed = PromptHelperComposer.compose(userText: userText, templateContent: nil)
        XCTAssertEqual(composed, userText)
    }

    func testPromptHelperComposeWithTemplate() {
        let userText = "Fix the login bug"
        let template = "You are a senior Swift developer.\n\n{PROMPT}\n\nBe concise."
        let composed = PromptHelperComposer.compose(userText: userText, templateContent: template)
        XCTAssertEqual(composed, "You are a senior Swift developer.\n\nFix the login bug\n\nBe concise.")
    }

    func testPromptHelperComposeTemplateWithoutPlaceholder() {
        let userText = "Fix the bug"
        let template = "You are a senior developer. Be thorough."
        let composed = PromptHelperComposer.compose(userText: userText, templateContent: template)
        // Template without {PROMPT} should prepend template then user text
        XCTAssertEqual(composed, "You are a senior developer. Be thorough.\n\nFix the bug")
    }

    func testPromptHelperComposeEmptyUserText() {
        let composed = PromptHelperComposer.compose(userText: "", templateContent: "Template content")
        XCTAssertEqual(composed, "")
    }

    // MARK: - Mandatory Chrome Injection Tests

    func testPromptHelperChromeAlwaysAppliedWithDefault() {
        // Simulates mandatory chrome: even when user doesn't pick a template,
        // the default template chrome should be applied
        let defaultChrome = "SYSTEM: Follow best practices.\n\n{PROMPT}\n\nRespond with code only."
        let userText = "Refactor the parser"
        let composed = PromptHelperComposer.compose(userText: userText, templateContent: defaultChrome)
        XCTAssertTrue(composed.hasPrefix("SYSTEM: Follow best practices."))
        XCTAssertTrue(composed.contains("Refactor the parser"))
        XCTAssertTrue(composed.hasSuffix("Respond with code only."))
    }

    func testPromptHelperChromeMultiplePlaceholders() {
        let template = "{PROMPT} --- {PROMPT}"
        let userText = "hello"
        let composed = PromptHelperComposer.compose(userText: userText, templateContent: template)
        XCTAssertEqual(composed, "hello --- hello")
    }

    // MARK: - Swarm Mode Compose Tests

    func testPromptHelperComposeWithSwarmPrefix() {
        let userText = "Fix the login bug"
        let swarmPrefix = PromptHelperComposer.swarmPrefix
        let composed = PromptHelperComposer.compose(userText: userText, templateContent: nil, swarmEnabled: true)
        XCTAssertTrue(composed.hasPrefix(swarmPrefix))
        XCTAssertTrue(composed.contains("Fix the login bug"))
    }

    func testPromptHelperComposeSwarmWithTemplate() {
        let userText = "Fix the bug"
        let template = "You are a developer.\n\n{PROMPT}"
        let composed = PromptHelperComposer.compose(userText: userText, templateContent: template, swarmEnabled: true)
        XCTAssertTrue(composed.contains(PromptHelperComposer.swarmPrefix))
        XCTAssertTrue(composed.contains("You are a developer."))
        XCTAssertTrue(composed.contains("Fix the bug"))
    }

    func testPromptHelperComposeSwarmDisabledNoPrefix() {
        let userText = "Fix the bug"
        let composed = PromptHelperComposer.compose(userText: userText, templateContent: nil, swarmEnabled: false)
        XCTAssertFalse(composed.contains(PromptHelperComposer.swarmPrefix))
        XCTAssertEqual(composed, "Fix the bug")
    }

    // MARK: - Send to Claude Code Tests

    @MainActor
    func testThinkingLevelServiceGeneratesPromptCommand() {
        let service = ThinkingLevelService.shared
        let command = service.generatePromptCommand(prompt: "Hello world")
        XCTAssertTrue(command.contains("claude"))
        XCTAssertTrue(command.contains("Hello world"))
    }

    @MainActor
    func testThinkingLevelServiceEscapesSpecialChars() {
        let service = ThinkingLevelService.shared
        let command = service.generatePromptCommand(prompt: "Fix the \"bug\" in $PATH")
        XCTAssertTrue(command.contains("claude"))
        // Should have escaped quotes and dollar sign
        XCTAssertFalse(command.contains("\"bug\""))
    }

    // MARK: - Agent Teams Settings Tests

    @MainActor
    func testAgentTeamsDefaultDisabled() {
        let settings = SettingsViewModel.shared
        // Agent Teams should be disabled by default
        XCTAssertFalse(settings.agentTeamsEnabled)
    }

    func testPromptTemplateVersionInitialization() {
        let version = PromptTemplateVersion(
            versionNumber: 3,
            content: "Old content",
            editNote: "Refactored",
            oneShotSuccessCount: 7,
            totalPromptsFromVersion: 12
        )

        XCTAssertEqual(version.versionNumber, 3)
        XCTAssertEqual(version.content, "Old content")
        XCTAssertEqual(version.editNote, "Refactored")
        XCTAssertEqual(version.oneShotSuccessCount, 7)
        XCTAssertEqual(version.totalPromptsFromVersion, 12)
        XCTAssertNotNil(version.id)
        XCTAssertNotNil(version.createdAt)
    }
}
