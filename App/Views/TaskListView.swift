import SwiftData
import SwiftUI
import WidgetKit

struct TaskListView: View {
    let source: SidebarItem

    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskItem]
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]

    @AppStorage("showCompleted") private var showCompleted = false
    @State private var selection = Set<PersistentIdentifier>()
    @State private var inspectedTask: TaskItem?
    @State private var editingList: TaskList?
    @State private var newTitle = ""
    @FocusState private var newTaskFocused: Bool
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        taskList
        #if os(iOS)
        .listStyle(.plain)
        #else
        .listStyle(.inset)
        .alternatingRowBackgrounds(.disabled)
        #endif
        .overlay {
            if sections.isEmpty && !canAddTasks {
                ContentUnavailableView("No Completed Tasks", systemImage: "checkmark.circle")
            }
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self, menu: contextMenu) { ids in
            if let task = tasks(for: ids).first { inspectedTask = task }
        }
        #if os(macOS)
        .onDeleteCommand { delete(tasks(for: selection)) }
        #endif
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar { toolbarContent }
        // Side inspector on iPad and Mac; a regular sheet on iPhone.
        .inspector(isPresented: usesInspector ? inspectorBinding : .constant(false)) {
            if let task = inspectedTask {
                TaskDetailView(task: task) { inspectedTask = nil }
                    .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
            }
        }
        .sheet(item: usesInspector ? .constant(nil) : $inspectedTask) { task in
            TaskDetailView(task: task) { inspectedTask = nil }
        }
        .sheet(item: $editingList) { list in ListEditorView(list: list) }
        .focusedSceneValue(\.newTaskAction, canAddTasks ? { newTaskFocused = true } : nil)
        .tint(tint)
    }

    // MARK: - List content

    private var taskList: some View {
        List(selection: $selection) {
            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.tasks) { task in
                        row(for: task)
                    }
                } header: {
                    if !section.title.isEmpty { Text(section.title) }
                }
            }

            if canAddTasks {
                newTaskRow
            }
        }
    }

    private func row(for task: TaskItem) -> some View {
        TaskRow(task: task, showsListName: showsListNames, onToggle: { toggle(task) })
            .tag(task.id)
            .swipeActions(edge: .trailing) {
                Button("Delete", systemImage: "trash", role: .destructive) { delete([task]) }
                Button("Details", systemImage: "info.circle") { inspectedTask = task }
            }
            .swipeActions(edge: .leading) {
                Button(task.isFlagged ? "Unflag" : "Flag", systemImage: task.isFlagged ? "flag.slash" : "flag") {
                    toggleFlag(task)
                }
                .tint(.orange)
            }
    }

    @ViewBuilder
    private func contextMenu(_ ids: Set<PersistentIdentifier>) -> some View {
        let tasks = tasks(for: ids)
        if tasks.count == 1, let task = tasks.first {
            Button("Show Details", systemImage: "info.circle") { inspectedTask = task }
            Button(task.isFlagged ? "Unflag" : "Flag", systemImage: "flag") { toggleFlag(task) }
        }
        if !tasks.isEmpty {
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { delete(tasks) }
        }
    }

    // MARK: - New task row

    private var newTaskRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(tint)
            TextField("New Task", text: $newTitle)
                .textFieldStyle(.plain)
                .focused($newTaskFocused)
                .onSubmit(addTask)
                .submitLabel(.next)
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
        .selectionDisabled()
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            newTaskFocused = false
            return
        }
        let task = TaskItem(title: title)
        switch source {
        case .list(let list):
            task.list = list
        case .smart(let smart):
            task.list = lists.first
            if smart == .today || smart == .scheduled { task.dueDate = Calendar.current.startOfDay(for: .now) }
            if smart == .flagged { task.isFlagged = true }
        }
        context.insert(task)
        taskDidChange(task)
        newTitle = ""
        newTaskFocused = true  // keep typing the next one, like Reminders
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                if source != .smart(.completed) {
                    Toggle("Show Completed", systemImage: "checkmark.circle", isOn: $showCompleted)
                }
                if case .list(let list) = source {
                    Button("Show List Info", systemImage: "info.circle") { editingList = list }
                }
                let completed = visibleCompletedTasks
                if !completed.isEmpty {
                    Divider()
                    Button("Clear \(completed.count) Completed", systemImage: "trash", role: .destructive) {
                        delete(completed)
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: - Data

    private struct TaskSection {
        let title: String
        let tasks: [TaskItem]
    }

    private var sections: [TaskSection] {
        switch source {
        case .smart(.completed):
            let done = SmartList.completed.tasks(from: allTasks)
            return done.isEmpty ? [] : [TaskSection(title: "", tasks: done)]
        case .smart(.scheduled):
            let grouped = Dictionary(grouping: SmartList.scheduled.tasks(from: allTasks)) {
                Calendar.current.startOfDay(for: $0.dueDate ?? .now)
            }
            return grouped.keys.sorted().map { day in
                TaskSection(title: dayTitle(day), tasks: grouped[day] ?? [])
            } + completedSection
        case .smart(let smart):
            return [TaskSection(title: "", tasks: smart.tasks(from: allTasks))] + completedSection
        case .list(let list):
            let open = (list.tasks ?? [])
                .filter { $0.parent == nil && !$0.isCompleted }
                .sorted { $0.sortIndex < $1.sortIndex }
            return [TaskSection(title: "", tasks: open)] + completedSection
        }
    }

    private var completedSection: [TaskSection] {
        guard showCompleted, !visibleCompletedTasks.isEmpty else { return [] }
        return [TaskSection(title: "Completed", tasks: visibleCompletedTasks)]
    }

    /// Completed tasks belonging to this list or smart list.
    private var visibleCompletedTasks: [TaskItem] {
        let done = SmartList.completed.tasks(from: allTasks)
        switch source {
        case .list(let list): return done.filter { $0.list == list }
        case .smart(.today): return done.filter { $0.dueDate.map(Calendar.current.isDateInToday) ?? false }
        case .smart(.scheduled): return done.filter { $0.dueDate != nil }
        case .smart(.flagged): return done.filter(\.isFlagged)
        case .smart: return done
        }
    }

    private func tasks(for ids: Set<PersistentIdentifier>) -> [TaskItem] {
        allTasks.filter { ids.contains($0.id) }
    }

    private func toggleFlag(_ task: TaskItem) {
        task.isFlagged.toggle()
        taskDidChange(task)
    }

    private func toggle(_ task: TaskItem) {
        withAnimation(.snappy) { task.toggleCompletion() }
        taskDidChange(task)
    }

    private func delete(_ tasks: [TaskItem]) {
        for task in tasks {
            if inspectedTask == task { inspectedTask = nil }
            ReminderScheduler.shared.cancel(task)
            context.delete(task)
        }
        selection.removeAll()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        if day < calendar.startOfDay(for: .now) { return "Overdue · " + day.formatted(.dateTime.month().day()) }
        return day.formatted(.dateTime.weekday(.wide).month().day())
    }

    // MARK: - Appearance

    private var title: String {
        switch source {
        case .smart(let smart): smart.title
        case .list(let list): list.name
        }
    }

    private var tint: Color {
        switch source {
        case .smart(let smart): smart == .all || smart == .completed ? .accentColor : smart.color
        case .list(let list): list.color.color
        }
    }

    private var canAddTasks: Bool { source != .smart(.completed) }

    private var showsListNames: Bool {
        if case .smart = source { return true }
        return false
    }

    private var usesInspector: Bool {
        #if os(iOS)
        sizeClass == .regular
        #else
        true
        #endif
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(get: { inspectedTask != nil }, set: { if !$0 { inspectedTask = nil } })
    }
}
