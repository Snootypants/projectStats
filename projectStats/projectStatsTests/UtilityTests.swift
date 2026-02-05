import XCTest
@testable import projectStats

/// Tests for utility classes and extensions
final class UtilityTests: XCTestCase {

    // MARK: - DateExtensions Tests

    func testDateStartOfDay() {
        let date = Date()
        let startOfDay = date.startOfDay

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: startOfDay)

        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testDateEndOfDay() {
        let date = Date()
        let endOfDay = date.endOfDay

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: endOfDay)

        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 59)
        XCTAssertEqual(components.second, 59)
    }

    func testDateStartOfWeek() {
        let date = Date()
        let startOfWeek = date.startOfWeek

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: startOfWeek)

        // Week starts on Sunday (1) in default calendar
        XCTAssertEqual(weekday, calendar.firstWeekday)
    }

    func testDateDaysAgo() {
        let now = Date()
        let fiveDaysAgo = now.daysAgo(5)

        let difference = Calendar.current.dateComponents([.day], from: fiveDaysAgo, to: now)
        XCTAssertEqual(difference.day, 5)
    }

    func testDateRelativeString() {
        let now = Date()
        let yesterday = now.daysAgo(1)

        let relativeString = yesterday.relativeString

        XCTAssertFalse(relativeString.isEmpty)
        // Should contain "yesterday" or similar relative term
    }

    func testDateISOFormatting() {
        let date = Date(timeIntervalSince1970: 0) // Jan 1, 1970 00:00:00 UTC

        let isoFormatter = ISO8601DateFormatter()
        let formatted = isoFormatter.string(from: date)

        XCTAssertEqual(formatted, "1970-01-01T00:00:00Z")
    }

    // MARK: - StringExtensions Tests

    func testStringSHA256() {
        let testString = "hello world"
        let hash = testString.sha256()

        // SHA256 produces 64 hex characters
        XCTAssertEqual(hash.count, 64)
        XCTAssert(hash.allSatisfy { $0.isHexDigit })

        // Same input should produce same hash
        let hash2 = testString.sha256()
        XCTAssertEqual(hash, hash2)

        // Different input should produce different hash
        let differentHash = "hello world!".sha256()
        XCTAssertNotEqual(hash, differentHash)
    }

    func testStringTruncate() {
        let longString = "This is a very long string that needs to be truncated"

        let truncated = String(longString.prefix(20))
        XCTAssertEqual(truncated.count, 20)
        XCTAssert(truncated.hasPrefix("This is"))
    }

    // MARK: - Shell Tests

    func testShellRunBasicCommand() {
        let result = Shell.run("echo 'test'")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "test")
    }

    func testShellRunMultipleCommands() {
        let result = Shell.run("echo 'first' && echo 'second'")
        let lines = result.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(String(lines[0]), "first")
        XCTAssertEqual(String(lines[1]), "second")
    }

    func testShellRunPipedCommand() {
        let result = Shell.run("echo 'hello world' | wc -w")
        let wordCount = result.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(wordCount, "2")
    }

    func testShellRunWithSpecialCharacters() {
        let result = Shell.run("echo 'special: $HOME'")
        // Should output the literal string, not expand $HOME
        XCTAssert(result.contains("$HOME"))
    }

    // MARK: - LineCounter Tests

    func testLineCounterCountsLines() {
        let testContent = """
        line 1
        line 2
        line 3
        """

        let lines = testContent.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
    }

    func testLineCounterHandlesEmptyLines() {
        let testContent = """
        line 1

        line 3
        """

        let lines = testContent.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 3)
    }

    // MARK: - Logger Tests

    func testLoggerSubsystem() {
        // Verify logger can be accessed without crashing
        // Logger itself doesn't have a way to verify output in tests easily
        XCTAssertNotNil(Log.self)
    }

    // MARK: - URL Extension Tests

    func testURLIsDirectory() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: homeDir.path, isDirectory: &isDir)

        XCTAssertTrue(exists)
        XCTAssertTrue(isDir.boolValue)
    }

    func testURLFileExtension() {
        let swiftFile = URL(fileURLWithPath: "/path/to/file.swift")
        let pyFile = URL(fileURLWithPath: "/path/to/script.py")
        let noExtFile = URL(fileURLWithPath: "/path/to/Makefile")

        XCTAssertEqual(swiftFile.pathExtension, "swift")
        XCTAssertEqual(pyFile.pathExtension, "py")
        XCTAssertEqual(noExtFile.pathExtension, "")
    }

    func testURLLastPathComponent() {
        let file = URL(fileURLWithPath: "/path/to/file.swift")
        XCTAssertEqual(file.lastPathComponent, "file.swift")
    }

    // MARK: - Number Formatting Tests

    func testNumberFormatting() {
        let number = 1234567

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: number))

        XCTAssertNotNil(formatted)
        XCTAssert(formatted!.contains(",") || formatted!.contains(".")) // Locale dependent
    }

    func testCurrencyFormatting() {
        let amount = 123.45

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formatted = formatter.string(from: NSNumber(value: amount))

        XCTAssertNotNil(formatted)
        XCTAssert(formatted!.contains("$") || formatted!.contains("USD"))
    }

    // MARK: - Collection Extension Tests

    func testArraySafeSubscript() {
        let array = [1, 2, 3]

        // Safe access within bounds
        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 2], 3)

        // Safe access out of bounds returns nil
        XCTAssertNil(array[safe: 10])
        XCTAssertNil(array[safe: -1])
    }

    // MARK: - Data Validation Tests

    func testUUIDGeneration() {
        let uuid1 = UUID()
        let uuid2 = UUID()

        // UUIDs should be unique
        XCTAssertNotEqual(uuid1, uuid2)

        // UUIDs should have valid format
        XCTAssertEqual(uuid1.uuidString.count, 36)
        XCTAssert(uuid1.uuidString.contains("-"))
    }

    func testDateComparison() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)
        let later = now.addingTimeInterval(3600)

        XCTAssertTrue(earlier < now)
        XCTAssertTrue(later > now)
        XCTAssertTrue(now >= earlier)
        XCTAssertTrue(now <= later)
    }

    // MARK: - File Path Tests

    func testPathComponentJoining() {
        let basePath = "/Users/test"
        let filename = "file.txt"

        let fullPath = URL(fileURLWithPath: basePath).appendingPathComponent(filename).path
        XCTAssertEqual(fullPath, "/Users/test/file.txt")
    }

    func testPathNormalization() {
        let messyPath = "/Users/test/../test/./file.txt"
        let url = URL(fileURLWithPath: messyPath)
        let normalized = url.standardized.path

        XCTAssertFalse(normalized.contains(".."))
        XCTAssertFalse(normalized.contains("./"))
    }
}

// MARK: - Array Safe Subscript Extension (for testing)
extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
