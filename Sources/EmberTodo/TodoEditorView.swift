#if canImport(SwiftUI)
import SwiftUI
import TodoCore

struct TodoEditorView: View {
    @EnvironmentObject private var store: TodoStore
    @Environment(\.dismiss) private var dismiss
    let existing: TodoItem?
    @State private var title: String
    @State private var notes: String
    @State private var priority: TodoPriority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date

    init(existing: TodoItem? = nil) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _priority = State(initialValue: existing?.priority ?? .normal)
        _hasDueDate = State(initialValue: existing?.dueDate != nil)
        _dueDate = State(initialValue: existing?.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("What needs doing?", text: $title).font(.headline)
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                Section("Details") {
                    Picker("Priority", selection: $priority) {
                        ForEach(TodoPriority.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate { DatePicker("Due", selection: $dueDate, displayedComponents: .date) }
                }
            }
            .navigationTitle(existing == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.fontWeight(.semibold).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        if var item = existing {
            item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            item.priority = priority
            item.dueDate = hasDueDate ? dueDate : nil
            store.update(item)
        } else {
            store.add(title: title, notes: notes, priority: priority, dueDate: hasDueDate ? dueDate : nil)
        }
        dismiss()
    }
}
#endif
