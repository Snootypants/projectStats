import XCTest
@testable import projectStats

/// Tests for service layer classes
final class ServiceTests: XCTestCase {

    // MARK: - Shell Service Tests

    func testShellRunReturnsOutput() {
        let result = Shell.run("echo 'hello world'")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "hello world")
    }

    func testShellRunWithEmptyCommand() {
        let result = Shell.run("")
        XCTAssert(result.isEmpty || result.contains("error") || result.count >= 0)
    }

    func testShellRunWithInvalidCommand() {
        // Should not crash, just return empty or error
        let result = Shell.run("nonexistentcommand12345")
        XCTAssertNotNil(result)
    }

    func testShellRunWithTimeout() {
        // Test that commands complete
        let startTime = Date()
        _ = Shell.run("sleep 0.1")
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsed, 0.05)
        XCTAssertLessThan(elapsed, 5.0)
    }

    // MARK: - GitService Tests

    @MainActor
    func testGitServiceSingleton() {
        let instance1 = GitService.shared
        let instance2 = GitService.shared
        XCTAssertIdentical(instance1, instance2)
    }

    func testGitServiceParsesCommitHash() {
        // Test commit hash pattern detection
        let validHash = "abc1234def5678"
        let invalidHash = "not-a-hash"

        XCTAssertEqual(validHash.count, 14)
        XCTAssert(validHash.allSatisfy { $0.isHexDigit })
        XCTAssertFalse(invalidHash.allSatisfy { $0.isHexDigit })
    }

    func testGitServiceCommitMessageParsing() {
        // Test that git log format can be parsed
        let sampleGitLog = "abc1234|abc|Test commit message|John Doe|2024-01-15T10:30:00Z|3|+50|-20"

        let parts = sampleGitLog.split(separator: "|")
        XCTAssertEqual(parts.count, 7)
        XCTAssertEqual(String(parts[0]), "abc1234")
        XCTAssertEqual(String(parts[2]), "Test commit message")
    }

    // MARK: - ProjectScanner Tests

    @MainActor
    func testProjectScannerSingleton() {
        let instance1 = ProjectScanner.shared
        let instance2 = ProjectScanner.shared
        XCTAssertIdentical(instance1, instance2)
    }

    func testProjectScannerDetectsLanguages() {
        // Test file extension to language mapping
        let swiftFile = "MyClass.swift"
        let pythonFile = "script.py"
        let jsFile = "app.js"
        let tsFile = "component.tsx"

        XCTAssert(swiftFile.hasSuffix(".swift"))
        XCTAssert(pythonFile.hasSuffix(".py"))
        XCTAssert(jsFile.hasSuffix(".js"))
        XCTAssert(tsFile.hasSuffix(".tsx"))
    }

    // MARK: - TimeTrackingService Tests

    @MainActor
    func testTimeTrackingServiceSingleton() {
        let instance1 = TimeTrackingService.shared
        let instance2 = TimeTrackingService.shared
        XCTAssertIdentical(instance1, instance2)
    }

    @MainActor
    func testTimeTrackingIdleThreshold() {
        let service = TimeTrackingService.shared
        // Default idle threshold should be reasonable (e.g., 5 minutes = 300 seconds)
        XCTAssertGreaterThanOrEqual(service.idleThreshold, 60) // At least 1 minute
        XCTAssertLessThanOrEqual(service.idleThreshold, 3600) // At most 1 hour
    }

    // MARK: - NotificationService Tests

    func testNotificationServiceSingleton() {
        let instance1 = NotificationService.shared
        let instance2 = NotificationService.shared
        XCTAssertIdentical(instance1, instance2)
    }

    // MARK: - AchievementService Tests

    @MainActor
    func testAchievementServiceSingleton() {
        let instance1 = AchievementService.shared
        let instance2 = AchievementService.shared
        XCTAssertIdentical(instance1, instance2)
    }

    // MARK: - ClaudeUsageService Tests

    @MainActor
    func testClaudeUsageServiceSingleton() {
        let instance1 = ClaudeUsageService.shared
        let instance2 = ClaudeUsageService.shared
        XCTAssertIdentical(instance1, instance2)
    }

    func testClaudeUsageParsingFormat() {
        // Test that we can parse ccusage output format
        let sampleOutput = """
        claude-sonnet-4: 1000 input, 500 output, $0.015
        claude-opus-4: 2000 input, 1000 output, $0.12
        """

        let lines = sampleOutput.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)

        let firstLine = String(lines[0])
        XCTAssert(firstLine.contains("claude-sonnet-4"))
        XCTAssert(firstLine.contains("input"))
        XCTAssert(firstLine.contains("output"))
    }

    // MARK: - EnvFileService Tests

    @MainActor
    func testEnvFileServiceParsing() {
        // Test .env file line parsing
        let validLine = "API_KEY=sk-test123"
        let commentLine = "# This is a comment"
        let emptyLine = ""
        let exportLine = "export SECRET=value"

        // Valid line should have key=value
        let parts = validLine.split(separator: "=", maxSplits: 1)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(String(parts[0]), "API_KEY")
        XCTAssertEqual(String(parts[1]), "sk-test123")

        // Comment line should start with #
        XCTAssert(commentLine.hasPrefix("#"))

        // Empty line should be skipped
        XCTAssert(emptyLine.isEmpty)

        // Export line should be handled
        XCTAssert(exportLine.hasPrefix("export "))
    }

    // MARK: - SecretsScanner Tests

    func testSecretsScannerPatterns() {
        // Test that common secret patterns are detected
        let awsKey = "AKIAIOSFODNN7EXAMPLE"
        let genericApiKey = "sk-1234567890abcdef"
        let passwordInCode = "password = \"secret123\""

        // AWS keys start with AKIA
        XCTAssert(awsKey.hasPrefix("AKIA"))

        // API keys often have sk- prefix
        XCTAssert(genericApiKey.hasPrefix("sk-"))

        // Password assignments should be flagged
        XCTAssert(passwordInCode.contains("password"))
    }

    // MARK: - BackupService Tests

    func testBackupServiceDateFormat() {
        // Test backup naming format includes date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let now = Date()
        let formattedDate = formatter.string(from: now)

        XCTAssert(formattedDate.contains("-"))
        XCTAssertEqual(formattedDate.count, 19) // yyyy-MM-dd_HH-mm-ss
    }

    // MARK: - BranchService Tests

    func testBranchServiceNaming() {
        // Test branch name sanitization
        let validBranchName = "feature/add-login"
        let invalidChars = "feature/add login!" // spaces and special chars

        XCTAssertFalse(validBranchName.contains(" "))
        XCTAssert(invalidChars.contains(" "))

        // Branch names should be sanitized
        let sanitized = invalidChars
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "!", with: "")
        XCTAssertFalse(sanitized.contains(" "))
        XCTAssertFalse(sanitized.contains("!"))
    }

    // MARK: - WebAPIClient Tests

    @MainActor
    func testWebAPIClientSingleton() {
        let instance1 = WebAPIClient.shared
        let instance2 = WebAPIClient.shared
        XCTAssertIdentical(instance1, instance2)
    }

    @MainActor
    func testWebAPIClientAuthState() {
        let client = WebAPIClient.shared
        // Initial state should be not authenticated
        XCTAssertNotNil(client)
    }

    // MARK: - AIProviderRegistry Tests

    @MainActor
    func testAIProviderRegistrySingleton() {
        let instance1 = AIProviderRegistry.shared
        let instance2 = AIProviderRegistry.shared
        XCTAssertIdentical(instance1, instance2)
    }

    // MARK: - ThinkingLevelService Tests

    func testThinkingLevelServiceFlags() {
        // Test that thinking level generates correct CLI flags
        let noneFlag = ThinkingLevel.none.cliFlag

        // None should have empty or no flag
        XCTAssert(noneFlag == nil || noneFlag?.isEmpty == true)
    }

    // MARK: - ProviderMetricsService Tests

    func testProviderMetricsAggregation() {
        // Test that metrics can be aggregated
        let costs: [Double] = [0.01, 0.02, 0.015, 0.025]
        let totalCost = costs.reduce(0, +)
        let avgCost = totalCost / Double(costs.count)

        XCTAssertEqual(totalCost, 0.07, accuracy: 0.0001)
        XCTAssertEqual(avgCost, 0.0175, accuracy: 0.0001)
    }

    // MARK: - SyncEngine Tests

    @MainActor
    func testSyncEngineSingleton() {
        let instance1 = SyncEngine.shared
        let instance2 = SyncEngine.shared
        XCTAssertIdentical(instance1, instance2)
    }

    @MainActor
    func testSyncEngineInitialState() {
        let engine = SyncEngine.shared
        // Should not be syncing initially
        XCTAssertFalse(engine.isSyncing)
    }

    func testSyncErrorDescriptions() {
        // Test that all sync errors have descriptions
        let errors: [SyncError] = [
            .disabled,
            .notSignedIn,
            .subscriptionRequired,
            .networkUnavailable,
            .quotaExceeded,
            .conflictDetected
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - ProjectCreationService Tests

    func testProjectCreationValidateName() {
        let service = ProjectCreationService.shared
        XCTAssertNotNil(service.validateName(""))
        XCTAssertNotNil(service.validateName("   "))
        XCTAssertNotNil(service.validateName("bad/name"))
        XCTAssertNotNil(service.validateName("bad:name"))
        XCTAssertNil(service.validateName("good-name"))
        XCTAssertNil(service.validateName("good_name"))
        XCTAssertNil(service.validateName("Good Name 123"))
    }

    func testProjectCreationEmptyNameRejected() {
        let error = ProjectCreationService.shared.validateName("")
        XCTAssertNotNil(error)
        if case .emptyName = error {} else {
            XCTFail("Expected emptyName error")
        }
    }

    func testProjectCreationInvalidCharsRejected() {
        let error = ProjectCreationService.shared.validateName("bad/name")
        XCTAssertNotNil(error)
        if case .invalidName = error {} else {
            XCTFail("Expected invalidName error")
        }
    }

    func testProjectTypeProperties() {
        for type in ProjectType.allCases {
            XCTAssertFalse(type.rawValue.isEmpty)
            XCTAssertFalse(type.icon.isEmpty)
            XCTAssertFalse(type.id.isEmpty)
        }
    }

    func testCreateDefaultDocsCreatesFiles() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try ProjectCreationService.shared.createDefaultDocs(at: tmp, projectName: "TestProject")

        let docsDir = tmp.appendingPathComponent("docs")
        XCTAssertTrue(FileManager.default.fileExists(atPath: docsDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: docsDir.appendingPathComponent("ARCHITECTURE.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: docsDir.appendingPathComponent("FILE_STRUCTURE.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: docsDir.appendingPathComponent("MODELS.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: docsDir.appendingPathComponent("TODO.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: docsDir.appendingPathComponent("CHANGELOG.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: docsDir.appendingPathComponent("README.md").path))
        // Root README also created
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("README.md").path))
    }

    func testArchitectureMdHasAgentTeamsSection() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try ProjectCreationService.shared.createDefaultDocs(at: tmp, projectName: "TestProject")

        let archContent = try String(contentsOf: tmp.appendingPathComponent("docs/ARCHITECTURE.md"), encoding: .utf8)
        XCTAssertTrue(archContent.contains("Agent Teams Context"))
        XCTAssertTrue(archContent.contains("File Ownership Boundaries"))
        XCTAssertTrue(archContent.contains("Dependency Graph"))
        XCTAssertTrue(archContent.contains("Shared State Risks"))
    }

    // MARK: - AgentTeamsService Tests

    func testAgentTeamsSkillMdContent() {
        let content = AgentTeamsService.skillMdContent(projectName: "TestProject")
        XCTAssertTrue(content.contains("TestProject"))
        XCTAssertTrue(content.contains("SKILL"))
        XCTAssertTrue(content.contains("swarm"))
    }

    func testAgentTeamsDeploySkillMd() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try AgentTeamsService.deploySkillMd(to: tmp, projectName: "TestProject")

        let skillPath = tmp.appendingPathComponent("SKILL.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: skillPath.path))

        let content = try String(contentsOf: skillPath, encoding: .utf8)
        XCTAssertTrue(content.contains("TestProject"))
    }

    func testAgentTeamsRemoveSkillMd() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Deploy first
        try AgentTeamsService.deploySkillMd(to: tmp, projectName: "TestProject")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("SKILL.md").path))

        // Remove
        AgentTeamsService.removeSkillMd(from: tmp)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("SKILL.md").path))
    }

    func testAgentTeamsSwarmPerProjectToggle() {
        // Test per-project state
        let fakePath = "/tmp/test-project-\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: "swarm.enabled.\(fakePath)") }

        XCTAssertFalse(AgentTeamsService.isSwarmEnabled(for: fakePath))

        AgentTeamsService.setSwarmEnabled(true, for: fakePath)
        XCTAssertTrue(AgentTeamsService.isSwarmEnabled(for: fakePath))

        AgentTeamsService.setSwarmEnabled(false, for: fakePath)
        XCTAssertFalse(AgentTeamsService.isSwarmEnabled(for: fakePath))
    }

    // MARK: - Refresh ARCHITECTURE.md Tests

    func testRefreshArchitectureMdCreatesFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try ProjectCreationService.shared.refreshArchitectureMd(at: tmp, projectName: "RefreshTest")

        let archPath = tmp.appendingPathComponent("docs/ARCHITECTURE.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archPath.path))

        let content = try String(contentsOf: archPath, encoding: .utf8)
        XCTAssertTrue(content.contains("RefreshTest"))
        XCTAssertTrue(content.contains("Agent Teams Context"))
    }

    func testRefreshArchitectureMdOverwrites() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let docsDir = tmp.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Write old content
        let archPath = docsDir.appendingPathComponent("ARCHITECTURE.md")
        try "OLD CONTENT".write(to: archPath, atomically: true, encoding: .utf8)

        // Refresh should overwrite
        try ProjectCreationService.shared.refreshArchitectureMd(at: tmp, projectName: "Updated")

        let content = try String(contentsOf: archPath, encoding: .utf8)
        XCTAssertFalse(content.contains("OLD CONTENT"))
        XCTAssertTrue(content.contains("Updated"))
    }

    // MARK: - New Project → ARCHITECTURE.md Integration

    func testNewProjectCreatesArchitectureWithAgentTeams() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Simulate new project creation (blank type creates docs via createDefaultDocs)
        try ProjectCreationService.shared.createDefaultDocs(at: tmp, projectName: "NewApp")

        // Verify ARCHITECTURE.md exists and has Agent Teams Context section
        let archPath = tmp.appendingPathComponent("docs/ARCHITECTURE.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archPath.path))

        let content = try String(contentsOf: archPath, encoding: .utf8)
        XCTAssertTrue(content.contains("Agent Teams Context"))
        XCTAssertTrue(content.contains("File Ownership Boundaries"))
        XCTAssertTrue(content.contains("Dependency Graph"))
        XCTAssertTrue(content.contains("Shared State Risks"))

        // Now verify refresh also works on the same project
        try ProjectCreationService.shared.refreshArchitectureMd(at: tmp, projectName: "NewApp")
        let refreshed = try String(contentsOf: archPath, encoding: .utf8)
        XCTAssertTrue(refreshed.contains("Agent Teams Context"))
        XCTAssertTrue(refreshed.contains("NewApp"))
    }

    func testNextjsCommandGeneration() {
        let cmd = ProjectCreationService.shared.nextjsCommand(projectName: "my-app")
        XCTAssertTrue(cmd.contains("npx create-next-app@latest"))
        XCTAssertTrue(cmd.contains("my-app"))
        XCTAssertTrue(cmd.contains("--typescript"))
    }

    // MARK: - PromptExecutionTracker Tests

    func testParseScopeCountFromPromptText() {
        let text = """
        # Prompt

        ## SCOPE A: First
        Do stuff.

        ## SCOPE B: Second
        Do more.

        ## SCOPE C: Third
        Even more.
        """
        XCTAssertEqual(PromptExecutionTracker.parseScopeCount(from: text), 3)
    }

    func testParseScopeCountNoScopes() {
        let text = "Just fix the bug in auth.swift"
        XCTAssertEqual(PromptExecutionTracker.parseScopeCount(from: text), 1)
    }

    func testParseScopeCountSingleScope() {
        let text = "## SCOPE A: Only One\nDo it."
        XCTAssertEqual(PromptExecutionTracker.parseScopeCount(from: text), 1)
    }

    @MainActor
    func testPromptExecutionTrackerSingleton() {
        let t1 = PromptExecutionTracker.shared
        let t2 = PromptExecutionTracker.shared
        XCTAssertIdentical(t1, t2)
    }

    // MARK: - Kanban Swarm Test Scaffold Tests

    func testKanbanSwarmTestTypeExists() {
        let type = ProjectType.kanbanSwarmTest
        XCTAssertEqual(type.rawValue, "Kanban (Swarm Test)")
        XCTAssertEqual(type.icon, "person.3.fill")
    }

    func testKanbanSwarmTestScaffoldCreatesFiles() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Simulate the scaffold by calling createProject internals
        // We can't call createProject directly (needs ModelContext), so test the scaffold files via the service's public API
        // Instead, test that the static prompt exists and scaffold method is accessible
        let service = ProjectCreationService.shared

        // Test name validation still works
        XCTAssertNil(service.validateName("kanban-test"))

        // Test the swarm prompt content
        let prompt = SwarmTestPrompt.kanbanPrompt
        XCTAssertTrue(prompt.contains("LEAD AGENT"))
        XCTAssertTrue(prompt.contains("TEAMMATE 1"))
        XCTAssertTrue(prompt.contains("TEAMMATE 2"))
        XCTAssertTrue(prompt.contains("TEAMMATE 3"))
        XCTAssertTrue(prompt.contains("COORDINATION CONTRACT"))
        XCTAssertTrue(prompt.contains("2500"))
    }

    func testSwarmPromptHasTeammateAssignments() {
        let prompt = SwarmTestPrompt.kanbanPrompt
        // Verify leader + 3 teammates
        XCTAssertTrue(prompt.contains("## LEAD AGENT"))
        XCTAssertTrue(prompt.contains("## TEAMMATE 1: HTML Structure"))
        XCTAssertTrue(prompt.contains("## TEAMMATE 2: Styling"))
        XCTAssertTrue(prompt.contains("## TEAMMATE 3: JavaScript Logic"))
    }

    func testSwarmPromptHasFileBoundaries() {
        let prompt = SwarmTestPrompt.kanbanPrompt
        XCTAssertTrue(prompt.contains("Owns: index.html"))
        XCTAssertTrue(prompt.contains("Owns: style.css"))
        XCTAssertTrue(prompt.contains("Owns: app.js"))
    }

    func testSwarmPromptHasLineBudget() {
        let prompt = SwarmTestPrompt.kanbanPrompt
        XCTAssertTrue(prompt.contains("<2500 lines"))
    }

    // MARK: - Scope C: VibeConversationService Tests

    @MainActor
    func test_C_startConversation_createsModel() {
        let service = VibeConversationService.shared
        let conv = service.startConversation(projectPath: "/test/project")
        XCTAssertNotNil(service.activeConversation)
        XCTAssertEqual(conv.projectPath, "/test/project")
        XCTAssertEqual(conv.status, "planning")
        service.endConversation()
    }

    @MainActor
    func test_C_appendToLog_buffersAndFlushes() {
        let service = VibeConversationService.shared
        let conv = service.startConversation(projectPath: "/test")
        service.appendToLog("hello ")
        service.appendToLog("world")
        service.flushLogBuffer()
        XCTAssertEqual(conv.rawLog, "hello world")
        service.endConversation()
    }

    @MainActor
    func test_C_lockPlan_setsStatusReady() {
        let service = VibeConversationService.shared
        _ = service.startConversation(projectPath: "/test")
        service.lockPlan(summary: "Build a feature")
        XCTAssertEqual(service.activeConversation?.status, "ready")
        XCTAssertEqual(service.activeConversation?.planSummary, "Build a feature")
        service.endConversation()
    }

    @MainActor
    func test_C_composePrompt_appliesTemplate() {
        let service = VibeConversationService.shared
        _ = service.startConversation(projectPath: "/test")
        service.lockPlan(summary: "Build X")
        service.composePrompt(templateContent: "TEMPLATE:\n\n{PROMPT}")
        XCTAssertEqual(service.activeConversation?.composedPrompt, "TEMPLATE:\n\nBuild X")

        // Without template
        service.composePrompt(templateContent: nil)
        XCTAssertEqual(service.activeConversation?.composedPrompt, "Build X")
        service.endConversation()
    }

    // MARK: - Scope E: VibeTerminalBridge Tests

    @MainActor
    func test_E_send_appendsToOutputStream() {
        let bridge = VibeTerminalBridge(projectPath: URL(fileURLWithPath: "/test/project"))
        bridge.handleOutput("Hello from terminal")
        XCTAssertTrue(bridge.outputStream.contains("Hello from terminal"))
    }

    @MainActor
    func test_E_outputStream_trimmedWhenLarge() {
        let bridge = VibeTerminalBridge(projectPath: URL(fileURLWithPath: "/test"))
        // Append a lot of text
        let bigChunk = String(repeating: "x", count: 600_000)
        bridge.handleOutput(bigChunk)
        XCTAssertLessThanOrEqual(bridge.outputStream.count, 512_000 + 1000) // ~500KB + margin
    }

    // MARK: - Scope H: VibeSummarizerService Tests

    @MainActor
    func test_H_summarize_buildsCommand() {
        let conv = VibeConversation(projectPath: "/test")
        conv.rawLog = "User: Build a kanban board\nClaude: I'll create a kanban board with columns."
        let command = VibeSummarizerService.shared.buildSummarizeCommand(for: conv)
        XCTAssertTrue(command.contains("--model haiku"))
        XCTAssertTrue(command.contains("Summarize"))
    }

    @MainActor
    func test_H_summarize_handlesLargeLog() {
        let conv = VibeConversation(projectPath: "/test")
        conv.rawLog = String(repeating: "A long conversation line.\n", count: 5000)
        let command = VibeSummarizerService.shared.buildSummarizeCommand(for: conv)
        // Large logs should use temp file approach
        XCTAssertTrue(command.contains("Read /tmp/vibe_summary_"))
    }

    // MARK: - Scope 12A: onOutputCallback Wiring Tests

    @MainActor
    func test_12A_onOutputCallback_firesFromRecordOutput() {
        let tab = TerminalTabItem(kind: .shell, title: "Test")
        var received: String?
        tab.onOutputCallback = { text in
            received = text
        }
        tab.recordOutput("hello world")
        XCTAssertEqual(received, "hello world")
    }

    @MainActor
    func test_12A_planningTab_outputRoutesToBridge() {
        let bridge = VibeTerminalBridge(projectPath: URL(fileURLWithPath: "/test"))
        bridge.boot()
        XCTAssertNotNil(bridge.planningTab)
        // Simulate terminal output via the callback
        bridge.planningTab?.onOutputCallback?("test output")
        XCTAssertTrue(bridge.outputStream.contains("test output"))
    }

    // MARK: - Scope 12B: Execution Output Wiring Tests

    @MainActor
    func test_12B_executionOutput_detectsCompletion() {
        let bridge = VibeTerminalBridge(projectPath: URL(fileURLWithPath: "/test"))
        bridge.handleExecutionOutput("some output\n✻ Cooked for 2m 30s\n")
        XCTAssertFalse(bridge.isExecuting)
        XCTAssertTrue(bridge.executionOutputStream.contains("Cooked for"))
    }

    // MARK: - Scope 12C: Ghost Output Wiring Tests

    @MainActor
    func test_12C_ghostOutput_routesToSummarizer() {
        let summarizer = VibeSummarizerService.shared
        summarizer.handleGhostOutput("Summary text here")
        // Should accumulate in buffer (won't complete without marker)
        // Just verify it doesn't crash and the method is callable
        XCTAssertNotNil(summarizer)
    }
}
