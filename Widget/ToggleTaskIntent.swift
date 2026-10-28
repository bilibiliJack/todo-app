import AppIntents
import SwiftData
import WidgetKit

/// Completes a task straight from the widget.
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    static var isDiscoverable = false

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID), let context = WidgetStore.container?.mainContext else {
            return .result()
        }
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.uuid == uuid })
        if let task = try context.fetch(descriptor).first {
            task.toggleCompletion()
            try context.save()
        }
        return .result()
    }
}
