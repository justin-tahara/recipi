import Foundation
import SwiftData
import Testing
@testable import RecipiKit

struct CookLogTests {
    @Test func loggingACookSetsLastCooked() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = Recipe(title: "Dal")
        context.insert(recipe)
        #expect(recipe.lastCookedAt == nil)

        let first = Date(timeIntervalSince1970: 1_000)
        let second = Date(timeIntervalSince1970: 2_000)
        recipe.logCook(on: second, in: context)
        recipe.logCook(on: first, photoData: Data([1, 2, 3]), note: "  Less salt  ", in: context)
        try context.save()

        #expect(recipe.lastCookedAt == second)
        #expect(recipe.sortedCookLogs.map(\.cookedAt) == [second, first])
        #expect(recipe.cookPhotos.count == 1)
        #expect(recipe.cookPhotos.first?.photoData == Data([1, 2, 3]))
        #expect(recipe.sortedCookLogs.last?.note == "Less salt")
    }

    @Test func deletingACookRecomputesLastCooked() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = Recipe(title: "Dal")
        context.insert(recipe)
        let older = recipe.logCook(on: Date(timeIntervalSince1970: 1_000), in: context)
        let newer = recipe.logCook(on: Date(timeIntervalSince1970: 2_000), in: context)

        recipe.deleteCookLog(newer, in: context)
        #expect(recipe.lastCookedAt == older.cookedAt)
        recipe.deleteCookLog(older, in: context)
        #expect(recipe.lastCookedAt == nil)
        #expect(recipe.sortedCookLogs.isEmpty)
    }

    @Test func deletingARecipeDeletesItsCooks() throws {
        let container = try RecipiStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let recipe = Recipe(title: "Dal")
        context.insert(recipe)
        recipe.logCook(in: context)
        try context.save()

        context.delete(recipe)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<CookLog>()) == 0)
    }
}

struct LibrarySortTests {
    private let day: TimeInterval = 86_400

    private func keys() -> [LibrarySort.Key] {
        let now = Date(timeIntervalSince1970: 100 * day)
        return [
            .init(title: "Banana bread", createdAt: now.addingTimeInterval(-3 * day), lastCookedAt: now.addingTimeInterval(-30 * day)),
            .init(title: "Apple pie", createdAt: now.addingTimeInterval(-1 * day), lastCookedAt: nil),
            .init(title: "Curry", createdAt: now.addingTimeInterval(-2 * day), lastCookedAt: now.addingTimeInterval(-1 * day)),
            .init(title: "Dumplings", createdAt: now.addingTimeInterval(-4 * day), lastCookedAt: nil),
        ]
    }

    private func titles(_ sort: LibrarySort) -> [String] {
        keys().sorted(by: sort.areInIncreasingOrder).map(\.title)
    }

    @Test func sortsByName() {
        #expect(titles(.title) == ["Apple pie", "Banana bread", "Curry", "Dumplings"])
    }

    @Test func sortsByRecentlyAdded() {
        #expect(titles(.recentlyAdded) == ["Apple pie", "Curry", "Banana bread", "Dumplings"])
    }

    @Test func sortsByCookingWithNeverCookedLast() {
        #expect(titles(.recentlyCooked) == ["Curry", "Banana bread", "Apple pie", "Dumplings"])
        #expect(titles(.notCookedInAWhile) == ["Banana bread", "Curry", "Apple pie", "Dumplings"])
    }
}
