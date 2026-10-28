import Foundation
import SwiftData
import UserNotifications

/// Schedules a local notification for each open task that has a due date in the future.
/// A task with a date but no time is reminded at 9:00 that day.
@MainActor
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderScheduler()
    nonisolated static let allDayReminderHour = 9
    /// iOS keeps at most 64 pending notifications per app.
    static let maxPending = 60

    private let center = UNUserNotificationCenter.current()

    func configure() {
        center.delegate = self
    }

    nonisolated static func fireDate(dueDate: Date?, hasDueTime: Bool, isCompleted: Bool,
                                     now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard !isCompleted, let dueDate else { return nil }
        let date = hasDueTime
            ? dueDate
            : calendar.date(bySettingHour: allDayReminderHour, minute: 0, second: 0, of: dueDate) ?? dueDate
        return date > now ? date : nil
    }

    static func fireDate(for task: TaskItem, now: Date = .now) -> Date? {
        fireDate(dueDate: task.dueDate, hasDueTime: task.hasDueTime, isCompleted: task.isCompleted, now: now)
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Call after any change to a task's date, completion, title or deletion.
    func update(_ task: TaskItem) {
        let id = task.uuid.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard !task.isDeleted, let date = Self.fireDate(for: task) else { return }
        let request = makeRequest(for: task, at: date)
        Task {
            await requestAuthorizationIfNeeded()
            try? await center.add(request)
        }
    }

    func cancel(_ task: TaskItem) {
        center.removePendingNotificationRequests(withIdentifiers: [task.uuid.uuidString])
    }

    /// Rebuilds every pending reminder, e.g. after changes synced from another device or made in the widget.
    func resync(_ context: ModelContext) {
        guard let tasks = try? context.fetch(FetchDescriptor<TaskItem>()) else { return }
        let upcoming = tasks
            .compactMap { task in Self.fireDate(for: task).map { (task, $0) } }
            .sorted { $0.1 < $1.1 }
            .prefix(Self.maxPending)
        let requests = upcoming.map { makeRequest(for: $0.0, at: $0.1) }
        Task {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            center.removeAllPendingNotificationRequests()
            for request in requests { try? await center.add(request) }
        }
    }

    private func makeRequest(for task: TaskItem, at date: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = task.title.isEmpty ? "Task" : task.title
        if !task.notes.isEmpty {
            content.body = task.notes
        } else if let list = task.list {
            content.body = list.name
        }
        content.sound = .default
        content.threadIdentifier = task.list?.uuid.uuidString ?? "inbox"
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: task.uuid.uuidString, content: content, trigger: trigger)
    }

    // Show reminders while the app is open, too.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
