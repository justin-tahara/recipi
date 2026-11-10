#if DEBUG
import Foundation
import RecipiKit
import SwiftData

/// A small library of made-up recipes, with drawn photos, cook history and a
/// grocery list, for the App Store screenshots. Only loaded when UI tests
/// launch the app with `-ui-testing -sample-library` (see `TestSupport`).
/// The recipes are written for recipi; none is copied from a site.
@MainActor
enum SampleLibrary {
    struct Sample {
        var title: String
        var summary: String
        var servings: Int?
        var yieldText: String?
        var prepMinutes: Int
        var cookMinutes: Int
        /// Read by `AutoTagger`, as an import's keywords would be.
        var tags: [String]
        var ingredients: [RecipeDraft.Line]
        var steps: [String]
        var notes = ""
        var isFavorite = false
        var addedDaysAgo: Double
        var cookedDaysAgo: [Double] = []
        var photo: SamplePhoto.Style
    }

    struct Grocery {
        var text: String
        var recipe: String?
        var isChecked = false
    }

    /// Adds the sample recipes and grocery list to `context`.
    static func seed(into context: ModelContext) {
        let now = Date.now
        let day: TimeInterval = 86_400
        for sample in samples {
            var draft = RecipeDraft(title: sample.title)
            draft.summary = sample.summary
            draft.servings = sample.servings
            draft.yieldText = sample.yieldText
            draft.prepTime = TimeInterval(sample.prepMinutes * 60)
            draft.cookTime = sample.cookMinutes > 0 ? TimeInterval(sample.cookMinutes * 60) : nil
            draft.totalTime = TimeInterval((sample.prepMinutes + sample.cookMinutes) * 60)
            draft.tags = sample.tags
            draft.ingredients = sample.ingredients
            draft.steps = sample.steps.map { RecipeDraft.Line($0) }

            let recipe = Recipe.insert(from: draft, photoData: SamplePhoto.jpeg(sample.photo), into: context)
            recipe.notes = sample.notes
            recipe.isFavorite = sample.isFavorite
            recipe.createdAt = now.addingTimeInterval(-sample.addedDaysAgo * day)
            recipe.updatedAt = recipe.createdAt
            for daysAgo in sample.cookedDaysAgo {
                recipe.logCook(on: now.addingTimeInterval(-daysAgo * day), in: context)
            }
        }
        // In this order on the list, oldest first.
        for (index, grocery) in groceries.enumerated() {
            let item = GroceryItem(text: grocery.text, recipeTitle: grocery.recipe)
            item.isChecked = grocery.isChecked
            item.createdAt = now.addingTimeInterval(TimeInterval(index - groceries.count) * 60)
            context.insert(item)
        }
        try? context.save()
    }

    static let groceries: [Grocery] = [
        Grocery(text: "1 lb boneless chicken thighs", recipe: "Weeknight Chicken Tacos"),
        Grocery(text: "8 small corn tortillas", recipe: "Weeknight Chicken Tacos"),
        Grocery(text: "1 cup shredded red cabbage", recipe: "Weeknight Chicken Tacos"),
        Grocery(text: "1 lime", recipe: "Weeknight Chicken Tacos"),
        Grocery(text: "2 cans cannellini beans", recipe: "Lemony White Bean Soup"),
        Grocery(text: "3 cups chopped kale", recipe: "Lemony White Bean Soup"),
        Grocery(text: "Oat milk"),
        Grocery(text: "Coffee beans"),
        Grocery(text: "1 onion", recipe: "Lemony White Bean Soup", isChecked: true),
        Grocery(text: "1 lemon", recipe: "Lemony White Bean Soup", isChecked: true),
        Grocery(text: "A dozen eggs", isChecked: true),
    ]

    static let samples: [Sample] = [
        Sample(
            title: "Miso Butter Salmon",
            summary: "Glossy, salty-sweet salmon on the table in about twenty minutes. Serve it over rice with something green.",
            servings: 2,
            prepMinutes: 10,
            cookMinutes: 12,
            tags: ["Dinner", "Japanese"],
            ingredients: [
                .init("2 salmon fillets, about 6 oz each"),
                .init("2 tbsp white miso", section: "Glaze"),
                .init("1 tbsp butter, softened", section: "Glaze"),
                .init("1 tbsp honey", section: "Glaze"),
                .init("1 tsp rice vinegar", section: "Glaze"),
                .init("1 green onion, thinly sliced", section: "To finish"),
                .init("1 tsp toasted sesame seeds", section: "To finish"),
            ],
            steps: [
                "Heat the oven to 425°F and line a small tray with parchment.",
                "Mash the miso, butter, honey and vinegar into a smooth paste.",
                "Pat the salmon dry, set it on the tray skin side down and spread the paste over the tops.",
                "Roast for 10 to 12 minutes, until the glaze is browned at the edges and the fish flakes.",
                "Scatter over the green onion and sesame seeds and serve right away.",
            ],
            notes: "Works with any thick fillet. Leftover glaze keeps a week in the fridge.",
            isFavorite: true,
            addedDaysAgo: 40,
            cookedDaysAgo: [3, 17, 31],
            photo: .init(
                dish: .plate, table: .init(0x59616B), cloth: .init(0xD9A441), food: .init(0xE9875A),
                base: .init(0xF3EFE6), garnish: [.init(0x5E8C3A), .init(0xF4E9D2), .init(0x3F6B2A)], seed: 11
            )
        ),
        Sample(
            title: "Lemony White Bean Soup",
            summary: "A pantry soup that tastes like more than a few cans. Even better the next day.",
            servings: 4,
            prepMinutes: 10,
            cookMinutes: 30,
            tags: ["Lunch", "Vegetarian", "Mediterranean"],
            ingredients: [
                .init("2 tbsp olive oil"),
                .init("1 onion, diced"),
                .init("3 cloves garlic, sliced"),
                .init("2 cans (15 oz) cannellini beans, drained"),
                .init("4 cups vegetable broth"),
                .init("3 cups chopped kale"),
                .init("1 lemon, zested and juiced"),
                .init("1/2 cup grated parmesan"),
            ],
            steps: [
                "Warm the oil in a large pot over medium heat and cook the onion until soft, about 8 minutes.",
                "Add the garlic and cook for a minute more.",
                "Add the beans and broth, bring to a simmer and cook for 15 minutes. Mash some of the beans against the pot to thicken it.",
                "Stir in the kale and cook until it wilts.",
                "Take it off the heat, stir in the lemon and parmesan, and season to taste.",
            ],
            addedDaysAgo: 25,
            cookedDaysAgo: [9],
            photo: .init(
                dish: .bowl, table: .init(0xE8DFD0), cloth: .init(0x6C8EAD), food: .init(0xE6D3A8),
                garnish: [.init(0x4F7A3A), .init(0x6E9A48), .init(0xF2C94C)], seed: 22
            )
        ),
        Sample(
            title: "Brown Butter Banana Bread",
            summary: "Nutty brown butter and very ripe bananas. Toast a slice and add a little more butter.",
            servings: 10,
            yieldText: "Makes 1 loaf",
            prepMinutes: 15,
            cookMinutes: 60,
            tags: ["Breakfast", "Snack"],
            ingredients: [
                .init("1/2 cup butter"),
                .init("3 very ripe bananas"),
                .init("2/3 cup brown sugar"),
                .init("1 egg"),
                .init("1 tsp vanilla extract"),
                .init("1 tsp baking soda"),
                .init("1/2 tsp salt"),
                .init("1 1/2 cups flour"),
                .init("1/2 cup chopped walnuts"),
            ],
            steps: [
                "Heat the oven to 350°F and grease a 9 by 5 inch loaf pan.",
                "Melt the butter in a small pan and keep cooking, swirling, until it smells nutty and turns golden brown. Let it cool a little.",
                "Mash the bananas in a bowl, then whisk in the brown butter, sugar, egg and vanilla.",
                "Stir in the baking soda, salt and flour until just combined, then fold in the walnuts.",
                "Bake for 55 to 65 minutes, until a skewer comes out clean. Cool in the pan for 15 minutes before slicing.",
            ],
            isFavorite: true,
            addedDaysAgo: 60,
            cookedDaysAgo: [12, 44],
            photo: .init(
                dish: .loaf, table: .init(0xC9D3C0), cloth: .init(0xD98BA0), food: .init(0xA8652F),
                garnish: [.init(0x5B3A1E), .init(0xE3B877)], seed: 33
            )
        ),
        Sample(
            title: "Sesame Cucumber Salad",
            summary: "Cold, crunchy and a little spicy. Make it while the rice cooks.",
            servings: 2,
            prepMinutes: 10,
            cookMinutes: 0,
            tags: ["Side", "Vegan", "Asian"],
            ingredients: [
                .init("2 Persian cucumbers"),
                .init("1/2 tsp salt"),
                .init("1 tbsp rice vinegar"),
                .init("1 tsp soy sauce"),
                .init("1 tsp toasted sesame oil"),
                .init("1/2 tsp sugar"),
                .init("1 tsp chili crisp"),
                .init("1 tsp sesame seeds"),
            ],
            steps: [
                "Smash the cucumbers lightly with the flat of a knife, then cut them into bite-size pieces.",
                "Toss with the salt and leave for 10 minutes, then pour off the water.",
                "Stir together the vinegar, soy sauce, sesame oil and sugar, and toss with the cucumbers.",
                "Top with the chili crisp and sesame seeds.",
            ],
            addedDaysAgo: 12,
            photo: .init(
                dish: .plate, table: .init(0xF0E4D4), cloth: .init(0x8AA27A), food: .init(0xB9D39A),
                garnish: [.init(0x5E8C3A), .init(0xC0392B), .init(0xF4E9D2)], seed: 44
            )
        ),
        Sample(
            title: "Weeknight Chicken Tacos",
            summary: "Spiced chicken thighs, crunchy cabbage and lime. Everyone builds their own.",
            servings: 4,
            prepMinutes: 15,
            cookMinutes: 15,
            tags: ["Dinner", "Mexican"],
            ingredients: [
                .init("1 lb boneless chicken thighs", section: "Chicken"),
                .init("1 tbsp chili powder", section: "Chicken"),
                .init("1 tsp ground cumin", section: "Chicken"),
                .init("1/2 tsp smoked paprika", section: "Chicken"),
                .init("1 tbsp olive oil", section: "Chicken"),
                .init("8 small corn tortillas", section: "To serve"),
                .init("1 cup shredded red cabbage", section: "To serve"),
                .init("1/2 cup sour cream", section: "To serve"),
                .init("1 lime, cut into wedges", section: "To serve"),
                .init("1/4 cup cilantro leaves", section: "To serve"),
            ],
            steps: [
                "Rub the chicken with the spices and a good pinch of salt.",
                "Cook in the oil in a hot skillet for 5 to 6 minutes a side, until charred and cooked through. Rest it for a few minutes, then slice.",
                "Warm the tortillas in a dry pan.",
                "Fill with the chicken, cabbage, sour cream and cilantro, with lime to squeeze over.",
            ],
            addedDaysAgo: 18,
            cookedDaysAgo: [1, 8],
            photo: .init(
                dish: .plate, table: .init(0xD9C2A3), cloth: .init(0xC8553D), food: .init(0x9A5A33),
                base: .init(0xE8CF94), garnish: [.init(0x8E3B7A), .init(0x6E9A48), .init(0xF5F1E6), .init(0x9BC53D)], seed: 55
            )
        ),
        Sample(
            title: "Tomato Basil Shakshuka",
            summary: "Eggs poached in a peppery tomato sauce. Bring the pan to the table with plenty of bread.",
            servings: 3,
            prepMinutes: 10,
            cookMinutes: 25,
            tags: ["Breakfast", "Vegetarian", "Middle Eastern"],
            ingredients: [
                .init("2 tbsp olive oil"),
                .init("1 red bell pepper, sliced"),
                .init("1 onion, sliced"),
                .init("2 cloves garlic, chopped"),
                .init("1 tsp ground cumin"),
                .init("1 can (28 oz) crushed tomatoes"),
                .init("6 eggs"),
                .init("1/4 cup torn basil"),
            ],
            steps: [
                "Cook the pepper and onion in the oil in a wide pan until soft, about 10 minutes.",
                "Add the garlic and cumin for a minute, then the tomatoes. Simmer until thick, about 10 minutes.",
                "Make six wells in the sauce and crack an egg into each.",
                "Cover and cook for 5 to 7 minutes, until the whites are set and the yolks still soft.",
                "Scatter with basil and serve from the pan.",
            ],
            addedDaysAgo: 7,
            photo: .init(
                dish: .bowl, table: .init(0x4E555E), cloth: .init(0xEDE6DA), food: .init(0xC0392B),
                garnish: [.init(0x4F7A3A), .init(0x6E9A48)], eggs: 3, seed: 66
            )
        ),
        Sample(
            title: "Crispy Smashed Potatoes",
            summary: "Boiled, smashed and roasted until the edges shatter.",
            servings: 4,
            prepMinutes: 10,
            cookMinutes: 50,
            tags: ["Side", "Vegan", "Gluten-free"],
            ingredients: [
                .init("1 1/2 lb baby potatoes"),
                .init("3 tbsp olive oil"),
                .init("1 tsp flaky salt"),
                .init("2 tbsp chopped parsley"),
            ],
            steps: [
                "Boil the potatoes in salted water until tender, about 20 minutes. Drain and let them steam dry.",
                "Heat the oven to 450°F. Press each potato flat on an oiled tray with the bottom of a glass.",
                "Drizzle with the oil and roast for 25 to 30 minutes, until deep golden and crisp.",
                "Finish with the salt and parsley.",
            ],
            addedDaysAgo: 3,
            photo: .init(
                dish: .plate, table: .init(0xEDE6DA), cloth: .init(0x6C8EAD), food: .init(0xD9A54A),
                garnish: [.init(0x4F7A3A), .init(0xF4EEDC), .init(0xB5782E)], seed: 77
            )
        ),
    ]
}
#endif
