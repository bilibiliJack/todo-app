import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]
    @State private var newSubtask = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $task.title)
                        .font(.headline)
                    TextField("Notes", text: $task.notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                Section {
                    Toggle(isOn: hasDate) {
                        DetailLabel("Date", symbol: "calendar", color: .red, value: dateSummary)
                    }
                    if task.dueDate != nil {
                        DatePicker("Date", selection: dueDate, displayedComponents: .date)
                            #if os(iOS)
                            .datePickerStyle(.graphical)
                            #endif
                    }
                    Toggle(isOn: hasTime) {
                        DetailLabel("Time", symbol: "clock.fill", color: .blue,
                                    value: task.hasDueTime ? task.dueDate?.formatted(date: .omitted, time: .shortened) : nil)
                    }
                    if task.hasDueTime {
                        DatePicker("Time", selection: dueDate, displayedComponents: .hourAndMinute)
                    }
                }

                Section {
                    Toggle(isOn: $task.isFlagged) {
                        DetailLabel("Flag", symbol: "flag.fill", color: .orange)
                    }
                    Picker(selection: $task.priority) {
                        ForEach(Priority.allCases) { Text($0.title).tag($0) }
                    } label: {
                        DetailLabel("Priority", symbol: "exclamationmark", color: .red)
                    }
                    if task.parent == nil {
                        Picker(selection: $task.list) {
                            Text("None").tag(TaskList?.none)
                            ForEach(lists) { list in
                                Text(list.name).tag(TaskList?.some(list))
                            }
                        } label: {
                            DetailLabel("List", symbol: "list.bullet", color: task.list?.color.color ?? .gray)
                        }
                    }
                }

                if task.parent == nil {
                    subtasksSection
                }

                Section {
                    Button("Delete Task", role: .destructive, action: deleteTask)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
        .onChange(of: task.isFlagged) { taskDidChange(task) }
        .onChange(of: task.priorityRaw) { taskDidChange(task) }
        .onChange(of: task.list) { taskDidChange(task) }
        .onDisappear { taskDidChange(task) }
    }

    private var subtasksSection: some View {
        Section("Subtasks") {
            ForEach(task.sortedSubtasks) { subtask in
                SubtaskRow(subtask: subtask)
            }
            .onDelete { offsets in
                let items = task.sortedSubtasks
                for index in offsets { context.delete(items[index]) }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
                TextField("Add Subtask", text: $newSubtask)
                    .onSubmit(addSubtask)
            }
        }
    }

    private func addSubtask() {
        let title = newSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let subtask = TaskItem(title: title, list: task.list, parent: task)
        context.insert(subtask)
        newSubtask = ""
    }

    private func deleteTask() {
        ReminderScheduler.shared.cancel(task)
        onClose()
        context.delete(task)
    }

    // MARK: - Date bindings

    private var dateSummary: String? {
        task.dueDate.map { TaskRow.format($0, hasTime: false) }
    }

    private var hasDate: Binding<Bool> {
        Binding {
            task.dueDate != nil
        } set: { isOn in
            if isOn {
                task.dueDate = Calendar.current.startOfDay(for: .now)
            } else {
                task.dueDate = nil
                task.hasDueTime = false
            }
            taskDidChange(task)
        }
    }

    private var hasTime: Binding<Bool> {
        Binding {
            task.hasDueTime
        } set: { isOn in
            let calendar = Calendar.current
            if isOn {
                // Default to the next full hour on the chosen day.
                let base = task.dueDate ?? .now
                let nextHour = calendar.component(.hour, from: .now) + 1
                task.dueDate = calendar.date(bySettingHour: min(nextHour, 23), minute: 0, second: 0, of: base)
                task.hasDueTime = true
            } else {
                task.dueDate = task.dueDate.map { calendar.startOfDay(for: $0) }
                task.hasDueTime = false
            }
            taskDidChange(task)
        }
    }

    private var dueDate: Binding<Date> {
        Binding {
            task.dueDate ?? .now
        } set: { newValue in
            task.dueDate = newValue
            taskDidChange(task)
        }
    }
}

private struct SubtaskRow: View {
    @Bindable var subtask: TaskItem

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation { subtask.toggleCompletion() }
            } label: {
                Image(systemName: subtask.isCompleted ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(subtask.isCompleted ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary.opacity(0.6)))
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(subtask.isCompleted ? "Mark as not completed" : "Mark as completed")

            TextField("Subtask", text: $subtask.title)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
        }
    }
}

/// A Settings-style row label: a white symbol on a rounded colored square, with an optional value below.
struct DetailLabel: View {
    let title: String
    let symbol: String
    let color: Color
    var value: String?

    init(_ title: String, symbol: String, color: Color, value: String? = nil) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.value = value
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                if let value {
                    Text(value).font(.footnote).foregroundStyle(.tint)
                }
            }
        }
    }
}
