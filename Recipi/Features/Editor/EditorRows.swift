import RecipiDesign
import RecipiKit
import SwiftUI

/// Which field in the editor has the keyboard. Rows are told apart by
/// their draft row id.
enum EditorField: Hashable {
    case title
    /// The main text of an ingredient, step or heading row.
    case row(UUID)
    case amount(UUID)
    case unit(UUID)
    case name(UUID)
    case newTag

    /// The row this field belongs to, if any.
    var rowID: UUID? {
        switch self {
        case .row(let id), .amount(let id), .unit(let id), .name(let id): id
        case .title, .newTag: nil
        }
    }
}

/// What VoiceOver can do to a row besides editing its text, since drag to
/// reorder and swipe actions are hard to reach from inside a text field.
struct RowActions {
    var toggleKindTitle: String
    var toggleKind: () -> Void
    var delete: () -> Void
    var moveUp: (() -> Void)?
    var moveDown: (() -> Void)?
}

extension View {
    fileprivate func rowAccessibilityActions(_ actions: RowActions) -> some View {
        accessibilityActions {
            if let moveUp = actions.moveUp {
                Button("Move up", action: moveUp)
            }
            if let moveDown = actions.moveDown {
                Button("Move down", action: moveDown)
            }
            Button(actions.toggleKindTitle, action: actions.toggleKind)
            Button("Delete", role: .destructive, action: actions.delete)
        }
    }
}

/// One ingredient: the whole line, and while it's being edited, the amount,
/// unit and name as their own fields underneath. Editing either side
/// updates the other.
struct IngredientRowEditor: View {
    let id: UUID
    let number: Int
    @Binding var text: String
    /// Shows the amount, unit and name fields.
    let isExpanded: Bool
    let actions: RowActions
    var focus: FocusState<EditorField?>.Binding

    @State private var parts = IngredientParts()
    @ScaledMetric(relativeTo: .body) private var amountWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var unitWidth: CGFloat = 72
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text("•")
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.Colors.accent)
                    .accessibilityHidden(true)
                TextField("e.g. 1 cup flour", text: $text, axis: .vertical)
                    .focused(focus, equals: .row(id))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .accessibilityLabel("Ingredient \(number)")
                    .rowAccessibilityActions(actions)
            }

            if isExpanded {
                partsEditor
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { parts = IngredientParts(parsing: text) }
        .onChange(of: text) { _, newValue in
            // Only re-split when the line was typed in directly; edits made
            // in the part fields already match it.
            if newValue != parts.line {
                parts = IngredientParts(parsing: newValue)
            }
        }
    }

    private var partsEditor: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.xs))
        return layout {
            partField("Amount", value: partBinding(.amount), field: .amount(id))
                .frame(width: isLarge ? nil : amountWidth)
                .keyboardType(.numbersAndPunctuation)
            partField("Unit", value: partBinding(.unit), field: .unit(id))
                .frame(width: isLarge ? nil : unitWidth)
            partField("Ingredient", value: partBinding(.name), field: .name(id))
        }
        .padding(.leading, Theme.Spacing.md)
    }

    private func partField(_ label: String, value: Binding<String>, field: EditorField) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Fonts.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textTertiary)
                .accessibilityHidden(true)
            TextField(label, text: value)
                .font(Theme.Fonts.meta)
                .foregroundStyle(Theme.Colors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(field != .name(id))
                .focused(focus, equals: field)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, 6)
                .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .accessibilityLabel("\(label), ingredient \(number)")
        }
    }

    private enum Part {
        case amount, unit, name
    }

    /// Writes a part straight into the line, so the line never lags behind.
    private func partBinding(_ part: Part) -> Binding<String> {
        Binding {
            switch part {
            case .amount: parts.amount
            case .unit: parts.unit
            case .name: parts.name
            }
        } set: { newValue in
            switch part {
            case .amount: parts.amount = newValue
            case .unit: parts.unit = newValue
            case .name: parts.name = newValue
            }
            text = parts.line
        }
    }
}

/// One step of the method, numbered like the recipe page.
struct StepRowEditor: View {
    let id: UUID
    let number: Int
    @Binding var text: String
    let actions: RowActions
    var focus: FocusState<EditorField?>.Binding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.accent)
                .frame(minWidth: 26, minHeight: 26)
                .background(Theme.Colors.accentSoft, in: Circle())
                .accessibilityHidden(true)
            TextField("Describe this step", text: $text, axis: .vertical)
                .focused(focus, equals: .row(id))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(3)
                .accessibilityLabel("Step \(number)")
                .rowAccessibilityActions(actions)
        }
    }
}

/// A section heading row, e.g. "For the sauce". Everything below it, up to
/// the next heading, belongs to it.
struct HeadingRowEditor: View {
    let id: UUID
    @Binding var text: String
    let actions: RowActions
    var focus: FocusState<EditorField?>.Binding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: "textformat")
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textTertiary)
                .accessibilityHidden(true)
            TextField("Section name", text: $text, axis: .vertical)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .focused(focus, equals: .row(id))
                .accessibilityLabel("Section heading")
                .rowAccessibilityActions(actions)
        }
        .padding(.top, Theme.Spacing.xxs)
    }
}

/// A Notion-style property line for the editor: icon and name on the left,
/// the field on the right. At the largest text sizes the field moves under
/// the name so neither gets squeezed.
struct EditorPropertyRow<Content: View>: View {
    let label: String
    let symbol: String
    let content: Content

    @ScaledMetric(relativeTo: .subheadline) private var labelWidth: CGFloat = 104
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ label: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm))
        layout {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: symbol)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(label)
                    .lineLimit(1)
            }
            .font(Theme.Fonts.meta)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(width: isLarge ? nil : labelWidth, alignment: .leading)
            .accessibilityHidden(true)

            content
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Hours and minutes for a prep, cook or total time. Both empty means the
/// time isn't set.
struct DurationField: View {
    let label: String
    @Binding var value: TimeInterval?

    @ScaledMetric(relativeTo: .body) private var fieldWidth: CGFloat = 44

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            numberField(hoursBinding, placeholder: "0", accessibilityLabel: "\(label) hours")
            Text("h")
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityHidden(true)
                .padding(.trailing, Theme.Spacing.xs)
            numberField(minutesBinding, placeholder: "0", accessibilityLabel: "\(label) minutes")
            Text("min")
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityHidden(true)
        }
    }

    private func numberField(_ text: Binding<String>, placeholder: String, accessibilityLabel: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(minWidth: fieldWidth)
            .fixedSize()
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 4)
            .background(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .accessibilityLabel(accessibilityLabel)
    }

    private var totalMinutes: Int {
        Int(((value ?? 0) / 60).rounded())
    }

    private var hoursBinding: Binding<String> {
        Binding {
            let hours = totalMinutes / 60
            return hours > 0 ? String(hours) : ""
        } set: { newValue in
            set(hours: Self.number(in: newValue), minutes: totalMinutes % 60)
        }
    }

    private var minutesBinding: Binding<String> {
        Binding {
            let minutes = totalMinutes % 60
            return minutes > 0 ? String(minutes) : ""
        } set: { newValue in
            set(hours: totalMinutes / 60, minutes: Self.number(in: newValue))
        }
    }

    private func set(hours: Int, minutes: Int) {
        let total = hours * 60 + minutes
        value = total > 0 ? TimeInterval(total * 60) : nil
    }

    private static func number(in text: String) -> Int {
        Int(String(text.filter(\.isASCII).filter(\.isNumber).prefix(4))) ?? 0
    }
}
