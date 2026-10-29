import RecipiDesign
import RecipiKit
import SwiftUI

/// "I have 2 lb": scales the whole recipe from how much of one ingredient
/// there is. Amounts in another unit of the same kind are converted.
struct HaveAmountSheet: View {
    let ingredient: ParsedIngredient
    /// Called with the factor and what it was set from, e.g. "2 lb chicken".
    let onScale: (Double, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var unit: String?
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("The recipe uses")
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(ingredient.original)
                        .font(Theme.Fonts.rowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("I have")
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    HStack(spacing: Theme.Spacing.sm) {
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($isAmountFocused)
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                            .accessibilityLabel("Amount you have")
                        if unitChoices.isEmpty {
                            Text(name)
                                .font(Theme.Fonts.body)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        } else {
                            Picker("Unit", selection: $unit) {
                                ForEach(unitChoices, id: \.self) { choice in
                                    Text(choice).tag(Optional(choice))
                                }
                            }
                            .pickerStyle(.menu)
                            .fixedSize()
                        }
                    }
                }

                Text(resultText)
                    .font(Theme.Fonts.meta)
                    .foregroundStyle(factor == nil ? Theme.Colors.textTertiary : Theme.Colors.textSecondary)
                    .contentTransition(.numericText())
                    .motion(Motion.snappy, value: factor)

                Spacer(minLength: 0)

                Button {
                    guard let factor else { return }
                    onScale(factor, reason)
                    dismiss()
                } label: {
                    Label("Scale recipe", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.recipiPrimary)
                .disabled(factor == nil)
            }
            .padding(Theme.Spacing.page)
            .background(Theme.Colors.background)
            .navigationTitle("Scale to what you have")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if unit == nil { unit = unitChoices.first }
                isAmountFocused = true
            }
        }
        .tint(Theme.Colors.accent)
    }

    private var unitChoices: [String] {
        IngredientScaling.unitChoices(for: ingredient)
    }

    private var name: String {
        IngredientScaling.itemName(of: ingredient)
    }

    private var factor: Double? {
        guard let amount = ScaleInput.amount(from: amountText),
              let factor = IngredientScaling.factor(for: ingredient, have: amount, unit: unit),
              factor <= ScaleInput.maximumFactor else { return nil }
        return factor
    }

    private var resultText: String {
        if let factor {
            return "Scales every ingredient \(IngredientScaling.multiplierLabel(factor))."
        }
        if ScaleInput.amount(from: amountText) != nil {
            return "That's more than recipi can scale to."
        }
        return "Type how much you have."
    }

    private var reason: String {
        let amount = amountText.trimmingCharacters(in: .whitespaces)
        return [amount, unit, name.isEmpty ? nil : name]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

/// Reads amounts people type: "2", "1.5", "1,5", "1 1/2", "½".
enum ScaleInput {
    static let maximumFactor = 100.0

    static func amount(from text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = IngredientParser.parse(cleaned).quantity, value > 0 else { return nil }
        return value
    }
}
