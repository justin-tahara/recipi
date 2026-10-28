import RecipiKit
import SwiftData
import SwiftUI
import UIKit

/// Full-screen, one step at a time, with the screen kept awake and a
/// checklist of ingredients to tick off as they go in.
struct CookingModeView: View {
    let recipe: Recipe
    let scale: Double

    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var checkedIngredients: Set<PersistentIdentifier> = []
    @State private var showsIngredients = false

    var body: some View {
        let steps = recipe.sortedSteps

        NavigationStack {
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Step \(index + 1) of \(steps.count)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let section = step.section {
                                Text(section)
                                    .font(.headline)
                            }
                            Text(step.text)
                                .font(.title2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Ingredients", systemImage: "checklist") { showsIngredients = true }
                }
            }
            .sheet(isPresented: $showsIngredients) {
                IngredientChecklist(
                    ingredients: recipe.sortedIngredients,
                    scale: scale,
                    checked: $checkedIngredients
                )
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

private struct IngredientChecklist: View {
    let ingredients: [Ingredient]
    let scale: Double
    @Binding var checked: Set<PersistentIdentifier>

    var body: some View {
        NavigationStack {
            List(ingredients) { ingredient in
                let isChecked = checked.contains(ingredient.persistentModelID)
                Button {
                    if isChecked {
                        checked.remove(ingredient.persistentModelID)
                    } else {
                        checked.insert(ingredient.persistentModelID)
                    }
                } label: {
                    Label {
                        Text(ingredient.parsed.scaled(by: scale))
                            .strikethrough(isChecked)
                            .foregroundStyle(isChecked ? .secondary : .primary)
                    } icon: {
                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Ingredients")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
