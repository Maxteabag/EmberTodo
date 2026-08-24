#if canImport(SwiftUI)
import SwiftUI

@main
struct EmberTodoApp: App {
    @StateObject private var store = TodoStore()

    var body: some Scene {
        WindowGroup {
            TodoListView()
                .environmentObject(store)
                .tint(.ember)
        }
    }
}

extension Color {
    static let ember = Color(red: 0.95, green: 0.32, blue: 0.18)
}
#else
@main
enum EmberTodoApp {
    static func main() {}
}
#endif
