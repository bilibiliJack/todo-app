import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    var showsListName = false
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "largecircle.fill.circle" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary.opacity(0.6)))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(task.isCompleted ? "Mark as not completed" : "Mark as completed")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if task.priority != .none {
                        Text(task.priority.marks)
                            .fontWeight(.bold)
                            .foregroundStyle(.tint)
                    }
                    Text(task.title.isEmpty ? "New Task" : task.title)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                }

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !metadata.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(metadata, id: \.text) { item in
                            Label(item.text, systemImage: item.symbol)
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(item.isAlert ? Color.red : Color.secondary)
                        }
                    }
                    .font(.footnote)
                }
            }

            Spacer(minLength: 0)

            if task.isFlagged {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                    .accessibilityLabel("Flagged")
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    private struct Meta {
        let text: String
        let symbol: String
        var isAlert = false
    }

    private var metadata: [Meta] {
        var items: [Meta] = []
        if let due = task.dueDate {
            items.append(Meta(text: Self.format(due, hasTime: task.hasDueTime), symbol: task.hasDueTime ? "clock" : "calendar",
                              isAlert: task.isOverdue()))
        }
        let subtasks = task.subtasks ?? []
        if !subtasks.isEmpty {
            let done = subtasks.filter(\.isCompleted).count
            items.append(Meta(text: "\(done) of \(subtasks.count)", symbol: "checklist"))
        }
        if showsListName, let list = task.list {
            items.append(Meta(text: list.name, symbol: "list.bullet"))
        }
        return items
    }

    static func format(_ date: Date, hasTime: Bool) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(date) {
            day = "Today"
        } else if calendar.isDateInTomorrow(date) {
            day = "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            day = "Yesterday"
        } else if calendar.isDate(date, equalTo: .now, toGranularity: .year) {
            day = date.formatted(.dateTime.month(.abbreviated).day())
        } else {
            day = date.formatted(date: .abbreviated, time: .omitted)
        }
        return hasTime ? "\(day), \(date.formatted(date: .omitted, time: .shortened))" : day
    }
}
