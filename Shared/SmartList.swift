import Foundation
import SwiftUI

/// Built-in lists computed from all tasks, shown as tiles at the top of the sidebar.
enum SmartList: String, CaseIterable, Identifiable, Hashable {
    case today, scheduled, all, flagged, completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .scheduled: "Scheduled"
        case .all: "All"
        case .flagged: "Flagged"
        case .completed: "Completed"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .scheduled: "calendar"
        case .all: "tray.fill"
        case .flagged: "flag.fill"
        case .completed: "checkmark"
        }
    }

    var color: Color {
        switch self {
        case .today: .blue
        case .scheduled: .red
        case .all: .gray
        case .flagged: .orange
        case .completed: .gray
        }
    }

    func includes(_ task: TaskItem, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard task.parent == nil else { return false }
        switch self {
        case .today:
            guard !task.isCompleted, let due = task.dueDate else { return false }
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return due < startOfTomorrow  // includes overdue tasks
        case .scheduled:
            return !task.isCompleted && task.dueDate != nil
        case .all:
            return !task.isCompleted
        case .flagged:
            return !task.isCompleted && task.isFlagged
        case .completed:
            return task.isCompleted
        }
    }

    /// Matching tasks in display order.
    func tasks(from all: [TaskItem], now: Date = .now, calendar: Calendar = .current) -> [TaskItem] {
        let matching = all.filter { includes($0, now: now, calendar: calendar) }
        switch self {
        case .today, .scheduled:
            return matching.sorted { ($0.dueDate ?? .distantFuture, $0.sortIndex) < ($1.dueDate ?? .distantFuture, $1.sortIndex) }
        case .completed:
            return matching.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .all, .flagged:
            return matching.sorted { $0.sortIndex < $1.sortIndex }
        }
    }
}
