import SwiftData
import SwiftUI
import WidgetKit

@main
struct TodoApp: App {
    @State private var auth = AuthManager()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer.makeShared(cloudSync: true)
        } catch {
            fatalError("Could not open the task store: \(error)")
        }
        ReminderScheduler.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
        }
        .modelContainer(container)
        .commands { TodoCommands() }
        #if os(macOS)
        .defaultSize(width: 980, height: 640)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(auth)
                .modelContainer(container)
        }
        #endif
    }
}

/// Call after editing a task so its reminder and the widget stay current.
@MainActor
func taskDidChange(_ task: TaskItem) {
    ReminderScheduler.shared.update(task)
    WidgetCenter.shared.reloadAllTimelines()
}

// MARK: - Menu commands

extension FocusedValues {
    @Entry var newTaskAction: (() -> Void)?
    @Entry var newListAction: (() -> Void)?
}

struct TodoCommands: Commands {
    @FocusedValue(\.newTaskAction) private var newTask
    @FocusedValue(\.newListAction) private var newList

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") { newTask?() }
                .keyboardShortcut("n")
                .disabled(newTask == nil)
            Button("New List") { newList?() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(newList == nil)
        }
    }
}
