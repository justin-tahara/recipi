import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

/// A recipe laid out like a Notion page: cover photo, big title, a short
/// property list, then ingredients, method and notes.
struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How much every amount is multiplied by; 1 is as written. Set by the
    /// servings stepper, the Scale menu, or "I have" on an ingredient.
    @State private var scale: Double = 1
    /// What the scale was set from, e.g. "2 lb chicken", for the banner.
    @State private var scaleReason: String?
    /// The ingredient whose "I have" sheet is open.
    @State private var scalingIngredient: Ingredient?
    @State private var isEnteringCustomScale = false
    @State private var isLoggingCook = false
    @State private var customScaleText = ""
    @State private var isCooking = false
    @State private var isEditing = false
    @State private var toastMessage: String?
    /// True once the big title has scrolled under the navigation bar, so the
    /// bar can show it instead.
    @State private var isTitleScrolledAway = false
    @State private var preferences = Preferences()
    /// Units picked for this recipe only. Nil follows the app setting.
    @State private var unitsOverride: MeasurementPreference?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if recipe.photoData != nil {
                    RecipePhoto(data: recipe.photoData, title: recipe.title)
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    TranslationBanner(recipe: recipe)
                    properties
                    ingredientsSection
                    methodSection
                    CookHistorySection(recipe: recipe) { isLoggingCook = true }
                    if !recipe.notes.isEmpty {
                        Callout(symbol: "lightbulb.fill", color: .yellow) {
                            Text(recipe.notes)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.top, recipe.photoData == nil ? Theme.Spacing.xs : Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.Colors.background)
        .detectsRecipeLanguage(recipe)
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .opacity(isTitleScrolledAway ? 1 : 0)
                    .motion(Motion.smooth, value: isTitleScrolledAway)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withMotion(Motion.bouncy, reduceMotion: reduceMotion) {
                        recipe.isFavorite.toggle()
                    }
                } label: {
                    Label(recipe.isFavorite ? "Unfavorite" : "Favorite", systemImage: recipe.isFavorite ? "heart.fill" : "heart")
                }
                .tint(recipe.isFavorite ? TagColor.pink.foreground : Theme.Colors.accent)
                .bounceEffect(value: recipe.isFavorite)
                .sensoryFeedback(.selection, trigger: recipe.isFavorite)

                Menu {
                    Button("Edit", systemImage: "pencil") { isEditing = true }
                    Button("Add to grocery list", systemImage: "cart.badge.plus", action: addToGroceryList)
                    Button("I made this", systemImage: "checkmark.seal") { isLoggingCook = true }
                    // No photos: a shared file leaves them out anyway.
                    ShareLink(
                        item: RecipeShareFile(recipe: BackupRecipe(recipe, includingPhotos: false)),
                        preview: SharePreview(displayTitle)
                    ) {
                        Label("Share recipe file", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isCooking = true
            } label: {
                Label("Start cooking", systemImage: "frying.pan")
            }
            .buttonStyle(.recipiPrimary)
            .shadow(color: Theme.Colors.accent.opacity(0.25), radius: 12, y: 6)
            .disabled(recipe.sortedSteps.isEmpty)
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xs)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background {
                LinearGradient(
                    colors: [Theme.Colors.background.opacity(0), Theme.Colors.background],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $isCooking) {
            CookingModeView(recipe: recipe, scale: scale, units: units)
        }
        .sheet(isPresented: $isEditing) {
            RecipeEditorView(recipe: recipe)
        }
        .toast($toastMessage, bottomPadding: 96)
        .sensoryFeedback(.success, trigger: toastMessage) { _, newValue in newValue != nil }
        .sheet(isPresented: $isLoggingCook) {
            LogCookSheet(recipe: recipe) {
                toastMessage = "Logged. Nice cooking."
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $scalingIngredient) { ingredient in
            HaveAmountSheet(ingredient: ingredient.parsed) { factor, reason in
                setScale(factor, reason: reason)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.Colors.background)
        }
        .alert("Scale by", isPresented: $isEnteringCustomScale) {
            TextField("Multiplier", text: $customScaleText)
                .keyboardType(.decimalPad)
            Button("Scale") {
                if let factor = ScaleInput.amount(from: customScaleText), factor <= ScaleInput.maximumFactor {
                    setScale(factor, reason: nil)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every amount is multiplied by this, for example 1.5 or 1/2.")
        }
    }

    // MARK: - Blocks

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if recipe.photoData == nil {
                // Like a Notion page icon.
                RecipePhoto(data: nil, title: recipe.title)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                    .accessibilityHidden(true)
            }
            Text(displayTitle)
                .font(Theme.Fonts.pageTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.frame(in: .scrollView).maxY < 0
                } action: { isScrolledAway in
                    isTitleScrolledAway = isScrolledAway
                }
            if !recipe.summary.isEmpty {
                Text(recipe.summary)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var properties: some View {
        let tags = recipe.sortedTags
        VStack(alignment: .leading, spacing: 0) {
            if let prepTime = recipe.prepTime {
                PropertyRow("Prep", symbol: "timer") { Text(RecipeFormat.duration(prepTime)) }
            }
            if let cookTime = recipe.cookTime {
                PropertyRow("Cook", symbol: "flame") { Text(RecipeFormat.duration(cookTime)) }
            }
            if let totalTime = recipe.totalTime {
                PropertyRow("Total", symbol: "clock") { Text(RecipeFormat.duration(totalTime)) }
            }
            if recipe.servings != nil {
                PropertyRow("Servings", symbol: "person.2") {
                    ServingsStepper(value: servingsBinding)
                        .fixedSize()
                        .accessibilityIdentifier("recipe.servings")
                }
            } else if let yieldText = recipe.yieldText, !yieldText.isEmpty {
                PropertyRow("Makes", symbol: "person.2") { Text(yieldText) }
            }
            if !recipe.sortedIngredients.isEmpty {
                PropertyRow("Scale", symbol: "arrow.up.left.and.arrow.down.right") {
                    scaleMenu
                }
                PropertyRow("Units", symbol: "ruler") {
                    unitsPicker
                }
            }
            if !tags.isEmpty {
                PropertyRow("Tags", symbol: "tag") {
                    FlowLayout(spacing: 6) {
                        ForEach(tags) { tag in
                            TagPill(tag.name, color: tag.color)
                        }
                    }
                }
            }
            if let lastCookedAt = recipe.lastCookedAt {
                PropertyRow("Last cooked", symbol: "checkmark.seal") {
                    Text(Self.lastCookedText(lastCookedAt, count: recipe.cookLogs?.count ?? 0))
                }
            }
            if let sourceURL = recipe.sourceURL {
                PropertyRow("Source", symbol: "link") {
                    Link(destination: sourceURL) {
                        Text(Self.displayHost(of: sourceURL))
                            .underline(color: Theme.Colors.border)
                            .lineLimit(1)
                    }
                    .accessibilityLabel("View original recipe")
                }
            }
        }
    }

    private var ingredientsSection: some View {
        let ingredients = recipe.sortedIngredients
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Ingredients") {
                Text("\(ingredients.count)")
                    .font(Theme.Fonts.label)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            if scale != 1 {
                scaleBanner
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    if let section = ingredient.section, index == 0 || ingredients[index - 1].section != section {
                        eyebrow(section)
                    }
                    ingredientRow(ingredient)
                }
            }
            .motion(Motion.bouncy, value: scale)
            .motion(Motion.smooth, value: units)
        }
    }

    private var methodSection: some View {
        let steps = recipe.sortedSteps
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader("Method")
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    if let section = step.section, index == 0 || steps[index - 1].section != section {
                        eyebrow(section)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.accent)
                            .frame(width: 26, height: 26)
                            .background(Theme.Colors.accentSoft, in: Circle())
                            .accessibilityLabel("Step \(index + 1)")
                        Text(TemperatureConverter.convert(step.text, to: units))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.eyebrow)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.top, Theme.Spacing.xs)
    }

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        let parsed = ingredient.parsed
        let parts = parsed.displayParts(scaledBy: scale, in: units)
        let row = HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text("•")
                .fontWeight(.bold)
                .foregroundStyle(Theme.Colors.accent)
                .accessibilityHidden(true)
            (Text(parts.amount).fontWeight(.semibold) + Text(parts.rest))
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        return Group {
            if parsed.quantity != nil {
                // Tapping an amount scales the recipe to what you have.
                Button {
                    scalingIngredient = ingredient
                } label: {
                    row
                }
                .buttonStyle(.pressable)
                .accessibilityHint("Scales the recipe to how much you have")
            } else {
                row
            }
        }
    }

    private var scaleBanner: some View {
        Callout(symbol: "arrow.up.left.and.arrow.down.right", color: .orange) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(scaleSummary)
                    .font(Theme.Fonts.meta)
                    .contentTransition(.numericText())
                Spacer(minLength: Theme.Spacing.xs)
                Button("Reset") {
                    setScale(1, reason: nil)
                }
                .font(Theme.Fonts.meta.weight(.semibold))
                .foregroundStyle(Theme.Colors.accent)
                .buttonStyle(.pressable)
            }
        }
    }

    private var scaleSummary: String {
        let label = IngredientScaling.multiplierLabel(scale)
        if let scaleReason {
            return "Scaled \(label) for \(scaleReason)"
        }
        return "Scaled \(label)"
    }

    private var scaleMenu: some View {
        Menu {
            ForEach([0.5, 1, 2, 3], id: \.self) { factor in
                Button(IngredientScaling.multiplierLabel(factor)) {
                    setScale(factor, reason: nil)
                }
            }
            Button("Custom…", systemImage: "slider.horizontal.3") {
                customScaleText = ""
                isEnteringCustomScale = true
            }
        } label: {
            HStack(spacing: 4) {
                Text(IngredientScaling.multiplierLabel(scale))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .foregroundStyle(Theme.Colors.textPrimary)
        }
        .accessibilityLabel("Scale")
        .accessibilityValue(IngredientScaling.multiplierLabel(scale))
    }

    private var servingsBinding: Binding<Int> {
        Binding {
            let base = recipe.servings ?? 1
            return min(99, max(1, Int((Double(base) * scale).rounded())))
        } set: { newValue in
            guard let base = recipe.servings, base > 0 else { return }
            scale = Double(newValue) / Double(base)
            scaleReason = nil
        }
    }

    private func setScale(_ factor: Double, reason: String?) {
        withMotion(Motion.bouncy, reduceMotion: reduceMotion) {
            scale = factor
            scaleReason = factor == 1 ? nil : reason
        }
    }

    private var unitsPicker: some View {
        Menu {
            Picker("Units", selection: Binding(get: { units }, set: { unitsOverride = $0 })) {
                ForEach(MeasurementPreference.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(units.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .foregroundStyle(Theme.Colors.textPrimary)
            .contentTransition(.opacity)
        }
        .accessibilityLabel("Units")
        .accessibilityValue(units.title)
        .sensoryFeedback(.selection, trigger: units)
    }

    // MARK: - Helpers

    private var units: MeasurementPreference {
        unitsOverride ?? preferences.measurements
    }

    private var displayTitle: String {
        recipe.title.isEmpty ? "Untitled recipe" : recipe.title
    }

    /// "3 weeks ago · 4 times".
    private static func lastCookedText(_ date: Date, count: Int) -> String {
        let when = date.formatted(.relative(presentation: .named))
        return count > 1 ? "\(when) · \(count) times" : when
    }

    private static func displayHost(of url: URL) -> String {
        let host = url.host() ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private func addToGroceryList() {
        let ingredients = recipe.sortedIngredients
        for ingredient in ingredients {
            modelContext.insert(GroceryItem(text: ingredient.parsed.display(scaledBy: scale, in: units), recipeTitle: recipe.title))
        }
        toastMessage = ingredients.count == 1
            ? "Added 1 item to Groceries"
            : "Added \(ingredients.count) items to Groceries"
    }
}
