import Foundation
import SwiftData
import SwiftUI

@Model
final class TaskList {
    var uuid: UUID = UUID()
    var name: String = ""
    var colorName: String = ListColor.blue.rawValue
    var symbolName: String = "list.bullet"
    var sortIndex: Double = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.list)
    var tasks: [TaskItem]? = []

    init(name: String, color: ListColor = .blue, symbolName: String = "list.bullet") {
        self.name = name
        self.colorName = color.rawValue
        self.symbolName = symbolName
        self.createdAt = .now
        self.sortIndex = Date.now.timeIntervalSinceReferenceDate
    }

    var color: ListColor {
        get { ListColor(rawValue: colorName) ?? .blue }
        set { colorName = newValue.rawValue }
    }

    /// Top-level tasks that are still open.
    var openTaskCount: Int {
        (tasks ?? []).filter { $0.parent == nil && !$0.isCompleted }.count
    }
}

enum ListColor: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }

    static let symbols = [
        "list.bullet", "bookmark.fill", "mappin", "gift.fill", "birthday.cake.fill", "graduationcap.fill",
        "backpack.fill", "pencil.and.ruler.fill", "doc.fill", "book.fill", "creditcard.fill", "banknote.fill",
        "dumbbell.fill", "figure.run", "fork.knife", "wineglass.fill", "pills.fill", "stethoscope",
        "house.fill", "building.2.fill", "cart.fill", "bag.fill", "airplane", "car.fill",
        "leaf.fill", "pawprint.fill", "music.note", "gamecontroller.fill", "desktopcomputer", "star.fill",
        "heart.fill", "lightbulb.fill",
    ]
}
