import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI
import UIKit

/// Full-screen, one step at a time, with the screen kept awake and a
/// checklist of ingredients to tick off as they go in.
struct CookingModeView: View {
    let recipe: Recipe
    let scale: Double
    let units: MeasurementPreference

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentStep = 0
    @State private var checkedIngredients: Set<PersistentIdentifier> = []
    @State private var showsIngredients = false
    @State private var isLoggingCook = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let steps = recipe.sortedSteps
        let ingredients = recipe.sortedIngredients

        NavigationStack {
            VStack(spacing: 0) {
                StepProgressBar(count: steps.count, current: currentStep)
                    .padding(.horizontal, Theme.Spacing.page)
                    .padding(.top, Theme.Spacing.xs)

                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        StepPage(step: step, number: index + 1, count: steps.count, units: units)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                controls(stepCount: steps.count)
            }
            .background(Theme.Colors.background)
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsIngredients = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                            if !ingredients.isEmpty {
                                Text("\(checkedIngredients.count)/\(ingredients.count)")
                                    .font(.subheadline.weight(.medium))
                                    .monospacedDigit()
                                    .contentTransition(.numericText(value: Double(checkedIngredients.count)))
                            }
                        }
                    }
                    .accessibilityLabel("Ingredients")
                    .accessibilityValue("\(checkedIngredients.count) of \(ingredients.count) added")
                }
            }
            .sheet(isPresented: $showsIngredients) {
                IngredientChecklist(
                    ingredients: ingredients,
                    scale: scale,
                    units: units,
                    checked: $checkedIngredients
                )
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.Colors.background)
            }
            .sensoryFeedback(.selection, trigger: currentStep)
            // Next and Back keep VoiceOver on the button, so read out the
            // step that's now showing.
            .onChange(of: currentStep) { _, step in
                guard steps.indices.contains(step) else { return }
                let text = TemperatureConverter.convert(steps[step].text, to: units)
                AccessibilityNotification.Announcement("Step \(step + 1) of \(steps.count). \(text)").post()
            }
            // Finishing offers to log the cook; either way cooking mode
            // closes once the sheet does.
            .sheet(isPresented: $isLoggingCook, onDismiss: { dismiss() }) {
                LogCookSheet(recipe: recipe, cancelTitle: "Skip")
                    .presentationDetents([.medium, .large])
            }
        }
        .tint(Theme.Colors.accent)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func controls(stepCount: Int) -> some View {
        let isLast = currentStep >= stepCount - 1
        let isLarge = dynamicTypeSize.isAccessibilitySize
        // Side by side normally; stacked at the accessibility sizes, where
        // "Next step" wouldn't fit beside Back.
        let layout = isLarge
            ? AnyLayout(VStackLayout(spacing: Theme.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.sm))
        return layout {
            Button {
                go(to: currentStep - 1)
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(.recipiSecondary)
            .frame(maxWidth: isLarge ? .infinity : 140)
            .disabled(currentStep == 0)

            Button {
                if isLast {
                    isLoggingCook = true
                } else {
                    go(to: currentStep + 1)
                }
            } label: {
                HStack(spacing: 6) {
                    Text(isLast ? "Finish" : "Next step")
                    Image(systemName: isLast ? "checkmark" : "chevron.right")
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.recipiPrimary)
            .accessibilityIdentifier("cooking.next")
        }
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
        .frame(maxWidth: 720)
    }

    private func go(to step: Int) {
        withMotion(Motion.smooth, reduceMotion: reduceMotion) {
            currentStep = step
        }
    }
}

/// One segment per step. Finished and current steps fill with the accent.
private struct StepProgressBar: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Theme.Colors.accent : Theme.Colors.fill)
                    .frame(height: 4)
            }
        }
        .motion(Motion.smooth, value: current)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("Step \(current + 1) of \(count)")
    }
}

private struct StepPage: View {
    let step: Step
    let number: Int
    let count: Int
    let units: MeasurementPreference

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Step \(number)")
                        .foregroundStyle(Theme.Colors.accent)
                    Text("of \(count)")
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .font(Theme.Fonts.eyebrow)
                .textCase(.uppercase)
                .tracking(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(number) of \(count)")
                .accessibilityAddTraits(.isHeader)

                if let section = step.section {
                    TagPill(section, accessibilityLabel: "Section, \(section)")
                }

                Text(TemperatureConverter.convert(step.text, to: units))
                    .font(Theme.Fonts.step)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(6)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }
}

private struct IngredientChecklist: View {
    let ingredients: [Ingredient]
    let scale: Double
    let units: MeasurementPreference
    @Binding var checked: Set<PersistentIdentifier>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ingredients) { ingredient in
                        row(for: ingredient)
                    }
                } header: {
                    progressHeader
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .sensoryFeedback(.selection, trigger: checked.count)
            .navigationTitle("Ingredients")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var progressHeader: some View {
        let done = ingredients.filter { checked.contains($0.persistentModelID) }.count
        let fraction = ingredients.isEmpty ? 0 : Double(done) / Double(ingredients.count)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("\(done) of \(ingredients.count) added")
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .contentTransition(.numericText(value: Double(done)))
            GeometryReader { proxy in
                Capsule()
                    .fill(Theme.Colors.fill)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Theme.Colors.accent)
                            .frame(width: proxy.size.width * fraction)
                    }
            }
            .frame(height: 4)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .motion(Motion.smooth, value: done)
        .textCase(nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ingredients added")
        .accessibilityValue("\(done) of \(ingredients.count)")
    }

    private func row(for ingredient: Ingredient) -> some View {
        let id = ingredient.persistentModelID
        let isChecked = checked.contains(id)
        return Button {
            withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                if isChecked {
                    checked.remove(id)
                } else {
                    checked.insert(id)
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Checkbox(isOn: isChecked)
                Text(ingredient.parsed.display(scaledBy: scale, in: units))
                    .strikethrough(isChecked, color: Theme.Colors.textTertiary)
                    .foregroundStyle(isChecked ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.Colors.background)
        .listRowSeparatorTint(Theme.Colors.divider)
        .checkedState(isChecked)
    }
}
