import Foundation
import Combine
import WidgetKit

class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let fileURL: URL
    private var fileWatcher: DispatchSourceFileSystemObject?

    static var storeURL: URL {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.artisanal.todo"
        ) {
            return groupURL.appendingPathComponent("todos.json")
        }
        // Fallback for unsigned/development builds
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("ArtisanalTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.json")
    }

    /// Production initializer — uses the default store path and starts file watching.
    convenience init() {
        self.init(fileURL: Self.storeURL, watch: true)
    }

    /// Testable initializer — accepts a custom file URL and optionally disables file watching.
    init(fileURL: URL, watch: Bool = false) {
        self.fileURL = fileURL
        load()
        if watch {
            startWatching()
        }
    }

    // Watches the JSON file for external writes (e.g. from the MCP server)
    // and reloads live without requiring an app restart.
    private func startWatching() {
        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.load()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileWatcher = source
    }

    // ISO 8601 formatters — the MCP server (JavaScript) writes dates with
    // fractional seconds ("2026-03-26T10:00:00.123Z") which Swift's default
    // ISO8601DateFormatter rejects. We try fractional first, then plain.
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static var flexibleISO8601: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = isoFormatterWithFractional.date(from: str) { return date }
            if let date = isoFormatterPlain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(str)"
            )
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = Self.flexibleISO8601
        if let decoded = try? decoder.decode([TodoItem].self, from: data) {
            items = decoded
        } else {
            print("[TodoStore] ⚠️ Failed to decode \(fileURL.path) — file may be corrupt")
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[TodoStore] ⚠️ Failed to save: \(error)")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[i].isCompleted {
            // Remove from current position and insert at front so it appears
            // at the top of the active list
            var restored = items.remove(at: i)
            restored.restore()
            items.insert(restored, at: 0)
        } else {
            items[i].complete()
        }
        save()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    var pending: [TodoItem] {
        items.filter { !$0.isCompleted }
    }

    var completed: [TodoItem] {
        items.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? $0.createdAt) < ($1.completedAt ?? $1.createdAt) }
    }
}
