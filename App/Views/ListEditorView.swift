import SwiftData
import SwiftUI

/// Creates a new list (`list == nil`) or edits an existing one.
struct ListEditorView: View {
    let list: TaskList?
    var onCreate: ((TaskList) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String
    @State private var color: ListColor
    @State private var symbolName: String

    init(list: TaskList?, onCreate: ((TaskList) -> Void)? = nil) {
        self.list = list
        self.onCreate = onCreate
        _name = State(initialValue: list?.name ?? "")
        _color = State(initialValue: list?.color ?? .blue)
        _symbolName = State(initialValue: list?.symbolName ?? "list.bullet")
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        ListIcon(symbolName: symbolName, color: color.color, size: 88)
                            .shadow(color: color.color.opacity(0.35), radius: 8, y: 4)
                        TextField("List Name", text: $name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(color.color)
                            .padding(.vertical, 10)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .textFieldStyle(.plain)
                            .onSubmit(save)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ListColor.allCases) { option in
                            Button { color = option } label: {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 36, height: 36)
                                    .padding(4)
                                    .overlay {
                                        if option == color { Circle().stroke(Color.secondary.opacity(0.6), lineWidth: 3) }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.rawValue.capitalized)
                            .accessibilityAddTraits(option == color ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ListColor.symbols, id: \.self) { symbol in
                            Button { symbolName = symbol } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(symbol == symbolName ? .white : .secondary)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(symbol == symbolName ? color.color : Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(list == nil ? "New List" : "List Info")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 600)
        #endif
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let list {
            list.name = trimmedName
            list.color = color
            list.symbolName = symbolName
        } else {
            let newList = TaskList(name: trimmedName, color: color, symbolName: symbolName)
            context.insert(newList)
            onCreate?(newList)
        }
        dismiss()
    }
}
