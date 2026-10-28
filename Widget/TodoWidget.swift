import SwiftData
import SwiftUI
import WidgetKit

@main
struct TodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

/// The widget reads the App Group store without CloudKit; the app owns syncing.
@MainActor
enum WidgetStore {
    static let container: ModelContainer? = try? ModelContainer.makeShared(cloudSync: false)
}

struct TaskSnapshot: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let hasDueTime: Bool
    let isOverdue: Bool
    let isFlagged: Bool
    let color: Color
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskSnapshot]
    let totalCount: Int

    static let placeholder = TodayEntry(date: .now, tasks: [
        TaskSnapshot(id: "1", title: "Buy groceries", dueDate: .now, hasDueTime: false, isOverdue: false, isFlagged: false, color: .blue),
        TaskSnapshot(id: "2", title: "Call the dentist", dueDate: .now, hasDueTime: true, isOverdue: false, isFlagged: true, color: .red),
        TaskSnapshot(id: "3", title: "Finish slides", dueDate: .now, hasDueTime: false, isOverdue: false, isFlagged: false, color: .green),
    ], totalCount: 3)
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { @MainActor in completion(Self.loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let entry = Self.loadEntry()
            // Refresh at midnight so tomorrow's tasks roll into Today.
            let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }

    @MainActor
    static func loadEntry() -> TodayEntry {
        guard let context = WidgetStore.container?.mainContext,
              let all = try? context.fetch(FetchDescriptor<TaskItem>()) else {
            return TodayEntry(date: .now, tasks: [], totalCount: 0)
        }
        let today = SmartList.today.tasks(from: all)
        let snapshots = today.prefix(12).map { task in
            TaskSnapshot(id: task.uuid.uuidString, title: task.title, dueDate: task.dueDate, hasDueTime: task.hasDueTime,
                         isOverdue: task.isOverdue(), isFlagged: task.isFlagged, color: task.list?.color.color ?? .blue)
        }
        return TodayEntry(date: .now, tasks: Array(snapshots), totalCount: today.count)
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("See and check off the tasks due today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    private var maxRows: Int {
        switch family {
        case .systemSmall: 3
        case .systemMedium: 4
        default: 10
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Today", systemImage: "calendar.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                Text(entry.totalCount, format: .number)
                    .font(.title2.bold())
                    .foregroundStyle(.blue)
            }

            if entry.tasks.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    Text("All done for today")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(maxRows)) { task in
                    HStack(spacing: 8) {
                        Button(intent: ToggleTaskIntent(taskID: task.id)) {
                            Image(systemName: "circle")
                                .font(.body)
                                .foregroundStyle(task.color)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(task.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            if family != .systemSmall, let due = task.dueDate, task.hasDueTime || task.isOverdue {
                                Text(task.hasDueTime ? due.formatted(date: .omitted, time: .shortened) : "Overdue")
                                    .font(.caption2)
                                    .foregroundStyle(task.isOverdue ? .red : .secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        if task.isFlagged {
                            Image(systemName: "flag.fill").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                }
                Spacer(minLength: 0)
                if entry.totalCount > maxRows {
                    Text("+\(entry.totalCount - maxRows) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview(as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry.placeholder
}
