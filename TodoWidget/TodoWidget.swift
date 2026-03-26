import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct TodoEntry: TimelineEntry {
    let date: Date
    let items: [TodoItem]
}

// MARK: - Provider

struct TodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: Date(), items: sampleItems)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        completion(TodoEntry(date: Date(), items: WidgetStore.load().filter { !$0.isCompleted }))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        let pending = WidgetStore.load().filter { !$0.isCompleted }
        let entry = TodoEntry(date: Date(), items: pending)
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var sampleItems: [TodoItem] {
        [
            TodoItem(title: "Buy fresh coffee beans"),
            TodoItem(title: "Read for 30 minutes"),
            TodoItem(title: "Call the dentist"),
            TodoItem(title: "Water the plants"),
            TodoItem(title: "Take a short walk"),
        ]
    }
}

// MARK: - Widget Entry View

struct TodoWidgetEntryView: View {
    let entry: TodoEntry
    @Environment(\.widgetFamily) var family

    var maxItems: Int {
        switch family {
        case .systemSmall:  return 3
        case .systemMedium: return 5
        default:            return 10
        }
    }

    var displayItems: [TodoItem] { Array(entry.items.prefix(maxItems)) }
    var overflow: Int { max(0, entry.items.count - maxItems) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            widgetHeader
            Rectangle()
                .fill(Color("AppPaperLine"))
                .frame(height: 0.5)
                .padding(.horizontal, 12)

            if entry.items.isEmpty {
                allDoneView
            } else {
                itemList
            }

            Spacer(minLength: 0)
        }
        .containerBackground(Color("AppBackground"), for: .widget)
    }

    // MARK: - Header

    var widgetHeader: some View {
        HStack {
            Text("todo")
                .font(.system(size: 13, weight: .light, design: .serif))
                .foregroundStyle(Color("AppPrimaryText"))
            Spacer()
            if !entry.items.isEmpty {
                Text("\(entry.items.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color("AppMutedText"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Item list (interactive)

    var itemList: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayItems.enumerated()), id: \.element.id) { idx, item in
                // Button(intent:) makes the row interactive inside the widget
                Button(intent: ToggleTodoIntent(todoID: item.id.uuidString)) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color("AppCheckboxBorder"), lineWidth: 1)
                                .frame(width: 11, height: 11)
                            // Checkmark shown for completed items during transition
                            if item.isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(Color("AppAccent"))
                            }
                        }
                        Text(item.title)
                            .font(.system(size: 11, weight: .regular, design: .serif))
                            .foregroundStyle(Color("AppPrimaryText"))
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if idx < displayItems.count - 1 {
                    Rectangle()
                        .fill(Color("AppPaperLine"))
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)
                }
            }

            if overflow > 0 {
                Text("+ \(overflow) more")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color("AppMutedText"))
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: - Empty state

    var allDoneView: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text("all done")
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .foregroundStyle(Color("AppMutedText"))
                // Tap + to add via the app
                Link(destination: URL(string: "todoapp://add")!) {
                    Text("add a task →")
                        .font(.system(size: 10))
                        .foregroundStyle(Color("AppAccent"))
                }
            }
            Spacer()
        }
        .padding(.top, 14)
    }
}

// MARK: - Widget Configuration

struct TodoWidget: Widget {
    let kind = "TodoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Artisanal Todo")
        .description("Your tasks, always at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

private let previewItems = [
    TodoItem(title: "Buy fresh coffee beans"),
    TodoItem(title: "Read for 30 minutes"),
    TodoItem(title: "Call the dentist"),
    TodoItem(title: "Water the plants"),
    TodoItem(title: "Take a short walk"),
    TodoItem(title: "Reply to emails"),
]

#Preview("Small", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoEntry(date: .now, items: previewItems)
}

#Preview("Medium", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoEntry(date: .now, items: previewItems)
}

#Preview("Large", as: .systemLarge) {
    TodoWidget()
} timeline: {
    TodoEntry(date: .now, items: previewItems)
}

#Preview("Empty", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoEntry(date: .now, items: [])
}
