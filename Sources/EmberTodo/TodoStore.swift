#if canImport(SwiftUI)
import Foundation
import TodoCore

@MainActor
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    private let storageKey = "ember.todo.items.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(title: String, notes: String, priority: TodoPriority, dueDate: Date?) {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        items.append(TodoItem(title: title, notes: notes, priority: priority, dueDate: dueDate))
        save()
    }

    func update(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].toggleCompleted()
        save()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
#endif
