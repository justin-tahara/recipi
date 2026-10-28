import RecipiKit
import SwiftData
import SwiftUI

@main
struct RecipiApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try RecipiStore.makeContainer()
        } catch {
            fatalError("Couldn't open the recipe store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Recipes", systemImage: "book") }
            GroceryListView()
                .tabItem { Label("Groceries", systemImage: "cart") }
        }
    }
}
