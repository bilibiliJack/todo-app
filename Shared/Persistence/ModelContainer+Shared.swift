import Foundation
import SwiftData

enum AppGroup {
    static let identifier = "group.com.wangminghai.todo"
}

extension ModelContainer {
    static let schema = Schema([TaskItem.self, TaskList.self])

    /// The store shared by the app and the widget, kept in the App Group container.
    ///
    /// The app passes `cloudSync: true`, which uses `.automatic`: SwiftData mirrors to the
    /// iCloud container named in the entitlements and stays local when there is none
    /// (local builds without a development team). The widget passes `false` so only one
    /// process runs the CloudKit sync engine.
    static func makeShared(cloudSync: Bool) throws -> ModelContainer {
        let database: ModelConfiguration.CloudKitDatabase = cloudSync ? .automatic : .none
        do {
            let config = ModelConfiguration(schema: schema, url: try storeURL(inGroup: true), cloudKitDatabase: database)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // No usable App Group container (for example an unsigned build): fall back to the
            // app's own Application Support folder. The widget won't see this data.
            let config = ModelConfiguration(schema: schema, url: try storeURL(inGroup: false), cloudKitDatabase: database)
            return try ModelContainer(for: schema, configurations: config)
        }
    }

    static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }

    private static func storeURL(inGroup: Bool) throws -> URL {
        let directory: URL
        if inGroup {
            guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
                throw CocoaError(.fileNoSuchFile)
            }
            directory = group.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        } else {
            directory = URL.applicationSupportDirectory
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "Todo.store")
    }
}
