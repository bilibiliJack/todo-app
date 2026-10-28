import Foundation
import SwiftData

/// A single to-do. Every stored property has a default and every relationship is
/// optional so the model can be mirrored to CloudKit.
@Model
final class TaskItem {
    var uuid: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    var hasDueTime: Bool = false
    var priorityRaw: Int = 0
    var isFlagged: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?
    var createdAt: Date = Date()
    var sortIndex: Double = 0

    var list: TaskList?
    var parent: TaskItem?
    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var subtasks: [TaskItem]? = []

    init(title: String = "", list: TaskList? = nil, dueDate: Date? = nil, parent: TaskItem? = nil) {
        self.title = title
        self.list = list
        self.dueDate = dueDate
        self.parent = parent
        self.createdAt = .now
        self.sortIndex = Date.now.timeIntervalSinceReferenceDate
    }

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var sortedSubtasks: [TaskItem] {
        (subtasks ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    func toggleCompletion() {
        isCompleted.toggle()
        completedAt = isCompleted ? .now : nil
    }

    func isOverdue(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !isCompleted, let dueDate else { return false }
        return hasDueTime ? dueDate < now : dueDate < calendar.startOfDay(for: now)
    }
}

enum Priority: Int, CaseIterable, Identifiable {
    case none = 0, low, medium, high

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    /// Exclamation marks shown before a task's title, like Reminders.
    var marks: String { String(repeating: "!", count: rawValue) }
}
