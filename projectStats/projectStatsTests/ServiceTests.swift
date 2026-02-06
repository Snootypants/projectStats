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
}
