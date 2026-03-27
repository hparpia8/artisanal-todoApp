import XCTest
@testable import TodoApp

final class TodoItemTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultValues() {
        let item = TodoItem(title: "Test task")
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.completedAt)
        XCTAssertFalse(item.title.isEmpty)
    }

    // MARK: - Complete / Restore

    func testComplete() {
        var item = TodoItem(title: "Task")
        item.complete()
        XCTAssertTrue(item.isCompleted)
        XCTAssertNotNil(item.completedAt)
    }

    func testRestore() {
        var item = TodoItem(title: "Task")
        item.complete()
        item.restore()
        XCTAssertFalse(item.isCompleted)
        XCTAssertNil(item.completedAt)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = TodoItem(title: "Encode me")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TodoItem.self, from: data)

        // ISO 8601 truncates to whole seconds, so compare fields individually
        // rather than relying on Date sub-second equality.
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.isCompleted, decoded.isCompleted)
        XCTAssertEqual(original.completedAt == nil, decoded.completedAt == nil)
        XCTAssertEqual(
            Int(original.createdAt.timeIntervalSince1970),
            Int(decoded.createdAt.timeIntervalSince1970)
        )
    }

    func testDecodesCompletedItem() throws {
        var original = TodoItem(title: "Done item")
        original.complete()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TodoItem.self, from: data)

        XCTAssertEqual(decoded.isCompleted, true)
        XCTAssertNotNil(decoded.completedAt)
        XCTAssertEqual(original.id, decoded.id)
    }

    /// Verify that Swift's default `.iso8601` decoder rejects fractional seconds.
    /// This documents the root cause of the persistence bug: JavaScript's
    /// `toISOString()` produces "2026-03-26T10:00:00.123Z" which `.iso8601` can't parse.
    func testDefaultISO8601RejectsFractionalSeconds() {
        let json = """
        {
            "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "title": "From MCP",
            "createdAt": "2026-03-26T10:00:00.123Z",
            "completedAt": null,
            "isCompleted": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // This SHOULD fail — proving the bug exists in the default strategy
        XCTAssertThrowsError(try decoder.decode(TodoItem.self, from: json),
            "Default .iso8601 should reject fractional seconds")
    }

    /// Verify that TodoStore's flexible decoder handles fractional seconds
    /// from the MCP server (JavaScript's toISOString()).
    func testTodoStoreDecoderHandlesFractionalSeconds() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let file = tmp.appendingPathComponent("todos.json")
        // Simulate what the MCP server writes — dates with milliseconds
        let json = """
        [{
            "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            "title": "From MCP",
            "createdAt": "2026-03-26T10:00:00.123Z",
            "completedAt": null,
            "isCompleted": false
        }]
        """
        try json.write(to: file, atomically: true, encoding: .utf8)

        let store = TodoStore(fileURL: file)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].title, "From MCP")
    }
}
