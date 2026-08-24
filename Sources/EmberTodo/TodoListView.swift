#if canImport(SwiftUI)
import SwiftUI
#if canImport(TodoCore)
import TodoCore
#endif

struct TodoListView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var filter: TodoFilter = .open
    @State private var showingComposer = false
    @State private var editingItem: TodoItem?

    private var visibleItems: [TodoItem] { TodoRules.filtered(store.items, by: filter) }
    private var openCount: Int { store.items.filter { !$0.isCompleted }.count }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                if visibleItems.isEmpty { emptyState } else { taskList }
                addButton
            }
            .navigationTitle("Ember Todo")
            .safeAreaInset(edge: .top) { filterBar }
            .sheet(isPresented: $showingComposer) { TodoEditorView() }
            .sheet(item: $editingItem) { TodoEditorView(existing: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(openCount) open")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(openCount) open tasks")
                }
            }
        }
    }

    private var filterBar: some View {
        Picker("Task filter", selection: $filter) {
            ForEach(TodoFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var taskList: some View {
        List {
            ForEach(visibleItems) { item in
                TodoRow(item: item, onToggle: { store.toggle(item) })
                    .contentShape(Rectangle())
                    .onTapGesture { editingItem = item }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { store.delete(item) } label: { Label("Delete", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { store.toggle(item) } label: {
                            Label(item.isCompleted ? "Reopen" : "Complete", systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        }.tint(item.isCompleted ? .blue : .green)
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(filter == .done ? "Nothing completed yet" : "Your day is clear", systemImage: filter == .done ? "checkmark.circle" : "sparkles")
        } description: {
            Text(filter == .done ? "Completed tasks will collect here." : "Add one small thing and build momentum.")
        } actions: {
            if filter != .done { Button("Add a task") { showingComposer = true }.buttonStyle(.borderedProminent) }
        }
    }

    private var addButton: some View {
        Button { showingComposer = true } label: {
            Image(systemName: "plus").font(.title2.bold()).frame(width: 58, height: 58)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
        .padding(22)
        .accessibilityLabel("Add task")
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(item.isCompleted ? Color.green : Color.secondary)
            }.buttonStyle(.plain).accessibilityLabel(item.isCompleted ? "Mark open" : "Mark complete")
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    if item.priority == .high { Circle().fill(Color.ember).frame(width: 7, height: 7).accessibilityHidden(true) }
                    Text(item.title).font(.body.weight(.semibold)).strikethrough(item.isCompleted).foregroundStyle(item.isCompleted ? .secondary : .primary)
                }
                if let dueDate = item.dueDate {
                    Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption).foregroundStyle(item.isOverdue ? Color.ember : Color.secondary)
                } else if !item.notes.isEmpty {
                    Text(item.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }.padding(.vertical, 5)
    }
}
#endif
