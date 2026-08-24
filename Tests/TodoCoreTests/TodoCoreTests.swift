import Foundation
import Testing
@testable import TodoCore

@Test func trimsInputAndTogglesCompletion() {
    var item = TodoItem(title: "  Ship it  ", notes: "  Ready  ")
    #expect(item.title == "Ship it")
    #expect(item.notes == "Ready")
    let completed = Date(timeIntervalSince1970: 100)
    item.toggleCompleted(at: completed)
    #expect(item.isCompleted)
    #expect(item.completedAt == completed)
    item.toggleCompleted(at: Date(timeIntervalSince1970: 200))
    #expect(item.completedAt == nil)
}

@Test func filtersAndSortsOpenTasksByPriorityThenDueDate() {
    let later = Date(timeIntervalSince1970: 500)
    let sooner = Date(timeIntervalSince1970: 200)
    let items = [
        TodoItem(title: "Done", isCompleted: true, priority: .high),
        TodoItem(title: "Low", priority: .low, dueDate: sooner),
        TodoItem(title: "High later", priority: .high, dueDate: later),
        TodoItem(title: "High sooner", priority: .high, dueDate: sooner)
    ]
    #expect(TodoRules.filtered(items, by: .open).map(\.title) == ["High sooner", "High later", "Low"])
    #expect(TodoRules.filtered(items, by: .done).map(\.title) == ["Done"])
}

