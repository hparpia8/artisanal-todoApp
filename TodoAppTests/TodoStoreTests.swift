import XCTest
@testable import TodoApp

final class TodoStoreTests: XCTestCase {

    var store: TodoStore!
    var testFile: URL!

    override func setUp() {
        super.setUp()
        // Use a temp file so tests don't touch real data
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        testFile = tmp.appendingPathComponent("todos.json")
        store = TodoStore(fileURL: testFile)
    }

    override func tearDown() {
        let dir = testFile.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    // MARK: - Add

    func testAddCreatesItem() {
        store.add("Buy milk")
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].title, "Buy milk")
        XCTAssertFalse(store.items[0].isCompleted)
    }

    func testAddTrimsWhitespace() {
        store.add("  Clean house  ")
        XCTAssertEqual(store.items[0].title, "Clean house")
    }

    func testAddEmptyStringIsIgnored() {
        store.add("")
        store.add("   ")
        XCTAssertTrue(store.items.isEmpty)
    }

    // MARK: - Toggle

    func testToggleCompletesItem() {
        store.add("Task")
        store.toggle(store.items[0])
        XCTAssertTrue(store.items[0].isCompleted)
        XCTAssertNotNil(store.items[0].completedAt)
    }

    func testToggleRestoresCompletedItem() {
        store.add("Task")
        store.toggle(store.items[0]) // complete
        store.toggle(store.items[0]) // restore — moves to front
        // After restore the item moves to index 0
        let restored = store.items[0]
        XCTAssertFalse(restored.isCompleted)
        XCTAssertNil(restored.completedAt)
    }

    // MARK: - Delete

    func testDelete() {
        store.add("A")
        store.add("B")
        let toDelete = store.items[0]
        store.delete(toDelete)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items[0].title, "B")
    }

    // MARK: - Computed properties

    func testPendingAndCompleted() {
        store.add("Pending task")
        store.add("Done task")
        store.toggle(store.items[1]) // complete "Done task"

        XCTAssertEqual(store.pending.count, 1)
        XCTAssertEqual(store.pending[0].title, "Pending task")
        XCTAssertEqual(store.completed.count, 1)
        XCTAssertEqual(store.completed[0].title, "Done task")
    }

    // MARK: - Persistence

    func testSaveAndReload() {
        store.add("Persist me")
        store.toggle(store.items[0]) // complete it

        // Create a new store from the same file — should load saved data
        let store2 = TodoStore(fileURL: testFile)
        XCTAssertEqual(store2.items.count, 1)
        XCTAssertEqual(store2.items[0].title, "Persist me")
        XCTAssertTrue(store2.items[0].isCompleted)
    }

    func testLoadFromEmptyFile() {
        // Store with no file should start empty
        let emptyFile = testFile.deletingLastPathComponent()
            .appendingPathComponent("empty.json")
        let emptyStore = TodoStore(fileURL: emptyFile)
        XCTAssertTrue(emptyStore.items.isEmpty)
    }

    func testLoadFromCorruptFile() {
        try? "not valid json".data(using: .utf8)!.write(to: testFile)
        let corruptStore = TodoStore(fileURL: testFile)
        XCTAssertTrue(corruptStore.items.isEmpty)
    }
}
