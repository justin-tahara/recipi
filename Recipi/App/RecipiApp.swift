import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

@main
struct RecipiApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try Self.makeContainer()
        } catch {
            fatalError("Couldn't open the recipe store: \(error)")
        }
    }

    private static func makeContainer() throws -> ModelContainer {
        #if DEBUG
        // Tests get a throwaway store and canned web pages. An unsigned
        // simulator build has no App Group or iCloud entitlement, so the
        // real store isn't available to them anyway.
        if TestSupport.isActive {
            TestSupport.stubNetwork()
            return try RecipiStore.makeContainer(inMemory: true)
        }
        #endif
        return try RecipiStore.makeContainer()
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
                .tabItem { Label("Recipes", systemImage: "book.closed") }
            GroceryListView()
                .tabItem { Label("Groceries", systemImage: "cart") }
        }
        .tint(Theme.Colors.accent)
    }
}
