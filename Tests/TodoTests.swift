import Foundation
import SwiftData
import Testing
@testable import Todo

@MainActor
struct SmartListTests {
    let container = try! ModelContainer.makeInMemory()
    let calendar = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)  // fixed "now" for stable tests

    private func task(_ title: String, due: Date? = nil, flagged: Bool = false, completed: Bool = false) -> TaskItem {
        let task = TaskItem(title: title, dueDate: due)
        task.isFlagged = flagged
        if completed { task.toggleCompletion() }
        container.mainContext.insert(task)
        return task
    }

    @Test func todayIncludesOverdueButNotTomorrow() {
        let overdue = task("overdue", due: now.addingTimeInterval(-3 * 86_400))
        let today = task("today", due: now)
        let tomorrow = task("tomorrow", due: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!)
        let doneToday = task("done", due: now, completed: true)

        let result = SmartList.today.tasks(from: [overdue, today, tomorrow, doneToday], now: now, calendar: calendar)
        #expect(result.map(\.title) == ["overdue", "today"])
    }

    @Test func scheduledAllFlaggedAndCompleted() {
        let dated = task("dated", due: now)
        let undated = task("undated")
        let flagged = task("flagged", flagged: true)
        let done = task("done", completed: true)
        let all = [dated, undated, flagged, done]

        #expect(SmartList.scheduled.tasks(from: all, now: now).map(\.title) == ["dated"])
        #expect(Set(SmartList.all.tasks(from: all, now: now).map(\.title)) == ["dated", "undated", "flagged"])
        #expect(SmartList.flagged.tasks(from: all, now: now).map(\.title) == ["flagged"])
        #expect(SmartList.completed.tasks(from: all, now: now).map(\.title) == ["done"])
    }

    @Test func subtasksStayOutOfSmartLists() {
        let parent = task("parent", due: now)
        let child = TaskItem(title: "child", dueDate: now, parent: parent)
        container.mainContext.insert(child)

        #expect(SmartList.today.tasks(from: [parent, child], now: now, calendar: calendar).map(\.title) == ["parent"])
        #expect(parent.subtasks?.count == 1)
    }

    @Test func toggleCompletionSetsTimestamp() {
        let item = task("t")
        item.toggleCompletion()
        #expect(item.isCompleted && item.completedAt != nil)
        item.toggleCompletion()
        #expect(!item.isCompleted && item.completedAt == nil)
    }

    @Test func overdueRespectsTime() {
        let earlierToday = task("a", due: now.addingTimeInterval(-60))
        earlierToday.hasDueTime = true
        let allDayToday = task("b", due: calendar.startOfDay(for: now))
        #expect(earlierToday.isOverdue(now: now, calendar: calendar))
        #expect(!allDayToday.isOverdue(now: now, calendar: calendar))
    }

    @Test func listCountsOnlyOpenTopLevelTasks() {
        let list = TaskList(name: "Home")
        container.mainContext.insert(list)
        let open = task("open")
        let done = task("done", completed: true)
        open.list = list
        done.list = list
        let child = TaskItem(title: "child", list: list, parent: open)
        container.mainContext.insert(child)
        #expect(list.openTaskCount == 1)
    }
}

struct ReminderTests {
    let calendar = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func timedReminderFiresAtDueTime() {
        let due = now.addingTimeInterval(3_600)
        #expect(ReminderScheduler.fireDate(dueDate: due, hasDueTime: true, isCompleted: false, now: now, calendar: calendar) == due)
    }

    @Test func allDayReminderFiresAtNine() throws {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let fire = try #require(ReminderScheduler.fireDate(dueDate: tomorrow, hasDueTime: false, isCompleted: false, now: now, calendar: calendar))
        #expect(calendar.component(.hour, from: fire) == ReminderScheduler.allDayReminderHour)
        #expect(calendar.isDate(fire, inSameDayAs: tomorrow))
    }

    @Test func noReminderForPastCompletedOrUndated() {
        #expect(ReminderScheduler.fireDate(dueDate: now.addingTimeInterval(-60), hasDueTime: true, isCompleted: false, now: now) == nil)
        #expect(ReminderScheduler.fireDate(dueDate: now.addingTimeInterval(3_600), hasDueTime: true, isCompleted: true, now: now) == nil)
        #expect(ReminderScheduler.fireDate(dueDate: nil, hasDueTime: false, isCompleted: false, now: now) == nil)
    }
}
