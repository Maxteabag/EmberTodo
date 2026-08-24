import Foundation

public enum TodoPriority: String, Codable, CaseIterable, Sendable {
    case low, normal, high
}

public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var notes: String
    public var isCompleted: Bool
    public var priority: TodoPriority
    public var dueDate: Date?
    public let createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(), title: String, notes: String = "",
        isCompleted: Bool = false, priority: TodoPriority = .normal,
        dueDate: Date? = nil, createdAt: Date = Date(), completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public var isOverdue: Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Date()
    }

    public mutating func toggleCompleted(at date: Date = Date()) {
        isCompleted.toggle()
        completedAt = isCompleted ? date : nil
    }
}

public enum TodoFilter: String, CaseIterable, Sendable {
    case all = "All"
    case open = "Open"
    case done = "Done"
}

public enum TodoRules {
    public static func filtered(_ items: [TodoItem], by filter: TodoFilter) -> [TodoItem] {
        let visible = items.filter {
            switch filter {
            case .all: true
            case .open: !$0.isCompleted
            case .done: $0.isCompleted
            }
        }
        return visible.sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            if $0.priority != $1.priority {
                let rank: [TodoPriority: Int] = [.high: 0, .normal: 1, .low: 2]
                return rank[$0.priority, default: 1] < rank[$1.priority, default: 1]
            }
            switch ($0.dueDate, $1.dueDate) {
            case let (left?, right?): return left < right
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return $0.createdAt > $1.createdAt
            }
        }
    }
}

