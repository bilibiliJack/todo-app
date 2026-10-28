import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Binding var showingNewList: Bool

    @Environment(\.modelContext) private var context
    @Query(sort: \TaskList.sortIndex) private var lists: [TaskList]
    @Query private var allTasks: [TaskItem]

    @State private var editingList: TaskList?
    @State private var listPendingDeletion: TaskList?
    @State private var showingSettings = false

    private let tileColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        List(selection: $selection) {
            Section {
                LazyVGrid(columns: tileColumns, spacing: 10) {
                    ForEach(SmartList.allCases) { smart in
                        SmartListTile(smart: smart,
                                      count: smart.tasks(from: allTasks).count,
                                      isSelected: selection == .smart(smart)) {
                            selection = .smart(smart)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("My Lists") {
                ForEach(lists) { list in
                    NavigationLink(value: SidebarItem.list(list)) {
                        ListRow(list: list)
                    }
                    .contextMenu {
                        Button("Show List Info", systemImage: "info.circle") { editingList = list }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) { listPendingDeletion = list }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) { listPendingDeletion = list }
                        Button("Info", systemImage: "info.circle") { editingList = list }
                    }
                }
                .onMove(perform: moveLists)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .navigationTitle("Lists")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button("Add List") { showingNewList = true }
            }
            #else
            ToolbarItem {
                Button("Add List", systemImage: "plus") { showingNewList = true }
                    .help("Add a new list")
            }
            #endif
        }
        #if os(macOS)
        .safeAreaInset(edge: .bottom) {
            Button { showingNewList = true } label: {
                Label("Add List", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        #endif
        .sheet(item: $editingList) { list in
            ListEditorView(list: list)
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        #endif
        .confirmationDialog(deleteTitle, isPresented: deleteDialogBinding, titleVisibility: .visible) {
            Button("Delete List", role: .destructive) {
                if let list = listPendingDeletion { delete(list) }
            }
        } message: {
            Text("This will delete all tasks in this list.")
        }
    }

    private var deleteTitle: String {
        "Delete “\(listPendingDeletion?.name ?? "")”?"
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(get: { listPendingDeletion != nil }, set: { if !$0 { listPendingDeletion = nil } })
    }

    private func delete(_ list: TaskList) {
        if selection == .list(list) { selection = nil }
        for task in list.tasks ?? [] { ReminderScheduler.shared.cancel(task) }
        context.delete(list)
        listPendingDeletion = nil
    }

    private func moveLists(from source: IndexSet, to destination: Int) {
        var reordered = lists
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, list) in reordered.enumerated() { list.sortIndex = Double(index) }
    }
}

private struct SmartListTile: View {
    let smart: SmartList
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Image(systemName: smart.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected ? smart.color : .white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(isSelected ? Color.white : smart.color))
                    Spacer()
                    Text(count, format: .number)
                        .font(.title2.bold())
                        .foregroundStyle(isSelected ? .white : .primary)
                        .contentTransition(.numericText())
                }
                Text(smart.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? smart.color : Color.tileBackground,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(smart.title), \(count) tasks")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ListRow: View {
    let list: TaskList

    var body: some View {
        HStack(spacing: 10) {
            ListIcon(list: list, size: 28)
            Text(list.name)
            Spacer()
            Text(list.openTaskCount, format: .number)
                .foregroundStyle(.secondary)
        }
    }
}

struct ListIcon: View {
    let symbolName: String
    let color: Color
    var size: CGFloat = 28

    init(list: TaskList, size: CGFloat = 28) {
        self.symbolName = list.symbolName
        self.color = list.color.color
        self.size = size
    }

    init(symbolName: String, color: Color, size: CGFloat) {
        self.symbolName = symbolName
        self.color = color
        self.size = size
    }

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.48, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color.gradient))
    }
}

extension Color {
    static var tileBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color.primary.opacity(0.07)
        #endif
    }
}
