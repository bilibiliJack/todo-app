import SwiftData
import SwiftUI
import WidgetKit

struct RootView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        Group {
            if auth.isSignedIn {
                MainView()
            } else {
                SignInView()
            }
        }
        .animation(.default, value: auth.isSignedIn)
        .task { await auth.refreshCredentialState() }
    }
}

enum SidebarItem: Hashable {
    case smart(SmartList)
    case list(TaskList)
}

struct MainView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    @State private var selection: SidebarItem?
    @State private var showingNewList = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, showingNewList: $showingNewList)
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
                #endif
        } detail: {
            if let selection {
                TaskListView(source: selection)
                    .id(selection)
            } else {
                ContentUnavailableView("No List Selected", systemImage: "checklist",
                                       description: Text("Choose a list from the sidebar."))
            }
        }
        .sheet(isPresented: $showingNewList) {
            ListEditorView(list: nil) { newList in selection = .list(newList) }
        }
        .focusedSceneValue(\.newListAction) { showingNewList = true }
        .onAppear(perform: selectDefaultList)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: ReminderScheduler.shared.resync(context)
            case .background: WidgetCenter.shared.reloadAllTimelines()
            default: break
            }
        }
    }

    /// iPad and Mac open on Today; iPhone starts at the sidebar, like Reminders.
    private func selectDefaultList() {
        guard selection == nil else { return }
        #if os(iOS)
        if sizeClass == .regular { selection = .smart(.today) }
        #else
        selection = .smart(.today)
        #endif
    }
}
