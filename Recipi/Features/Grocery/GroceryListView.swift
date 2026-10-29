import RecipiDesign
import RecipiKit
import SwiftData
import SwiftUI

struct GroceryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \GroceryItem.createdAt) private var items: [GroceryItem]

    @State private var newItemText = ""
    @State private var remindersMessage: String?
    @State private var isSendingToReminders = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    addItemRow
                }

                if items.isEmpty {
                    Section {
                        EmptyStateView(
                            symbol: "cart",
                            title: "Nothing to buy",
                            message: "Add items here, or add a recipe's ingredients from its page.",
                            color: .green
                        )
                        .padding(.top, Theme.Spacing.xl)
                        .listRowBackground(Theme.Colors.background)
                        .listRowSeparator(.hidden)
                    }
                }

                if !uncheckedItems.isEmpty {
                    Section {
                        ForEach(uncheckedItems) { item in
                            GroceryRow(item: item)
                        }
                        .onDelete { offsets in delete(offsets, from: uncheckedItems) }
                    } header: {
                        sectionHeader("To buy", count: uncheckedItems.count)
                    }
                    .listSectionSeparator(.hidden)
                }

                if !checkedItems.isEmpty {
                    Section {
                        ForEach(checkedItems) { item in
                            GroceryRow(item: item)
                        }
                        .onDelete { offsets in delete(offsets, from: checkedItems) }
                    } header: {
                        sectionHeader("In the cart", count: checkedItems.count)
                    }
                    .listSectionSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Send to Reminders", systemImage: "checklist") {
                            Task { await sendToReminders() }
                        }
                        .disabled(uncheckedItems.isEmpty || isSendingToReminders)

                        Button("Clear checked items", systemImage: "trash", role: .destructive, action: clearChecked)
                            .disabled(checkedItems.isEmpty)
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .alert(
                "Reminders",
                isPresented: Binding(get: { remindersMessage != nil }, set: { if !$0 { remindersMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(remindersMessage ?? "")
            }
        }
    }

    private var addItemRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 22)
                .accessibilityHidden(true)
            TextField("Add an item", text: $newItemText)
                .foregroundStyle(Theme.Colors.textPrimary)
                .onSubmit(addItem)
                .submitLabel(.done)
        }
        .listRowBackground(Theme.Colors.background)
        .listRowSeparator(.hidden)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("\(count)")
                .foregroundStyle(Theme.Colors.textTertiary)
                .contentTransition(.numericText(value: Double(count)))
        }
        .font(Theme.Fonts.eyebrow)
        .textCase(.uppercase)
        .tracking(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(count == 1 ? "1 item" : "\(count) items")")
        .accessibilityAddTraits(.isHeader)
    }

    private var uncheckedItems: [GroceryItem] {
        items.filter { !$0.isChecked }
    }

    private var checkedItems: [GroceryItem] {
        items.filter(\.isChecked)
    }

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withMotion(Motion.snappy, reduceMotion: reduceMotion) {
            modelContext.insert(GroceryItem(text: text))
        }
        newItemText = ""
    }

    private func delete(_ offsets: IndexSet, from list: [GroceryItem]) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }

    private func clearChecked() {
        withMotion(Motion.snappy, reduceMotion: reduceMotion) {
            for item in items where item.isChecked {
                modelContext.delete(item)
            }
        }
    }

    private func sendToReminders() async {
        isSendingToReminders = true
        defer { isSendingToReminders = false }
        let texts = uncheckedItems.map(\.text)
        do {
            let count = try await RemindersExporter.export(texts, toListNamed: "Groceries")
            remindersMessage = "Added \(count) items to your Groceries list in Reminders."
        } catch {
            remindersMessage = error.localizedDescription
        }
    }
}

/// Ticking an item moves it down to "In the cart".
private struct GroceryRow: View {
    @Bindable var item: GroceryItem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withMotion(Motion.snappy, reduceMotion: reduceMotion) {
                item.isChecked.toggle()
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Checkbox(isOn: item.isChecked)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.text)
                        .strikethrough(item.isChecked, color: Theme.Colors.textTertiary)
                        .foregroundStyle(item.isChecked ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    if let recipeTitle = item.recipeTitle, !recipeTitle.isEmpty {
                        TagPill(recipeTitle, accessibilityLabel: "From \(recipeTitle)")
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("grocery.item")
        .sensoryFeedback(.selection, trigger: item.isChecked)
        .listRowBackground(Theme.Colors.background)
        .listRowSeparatorTint(Theme.Colors.divider)
        .checkedState(item.isChecked)
        .accessibilityHint(item.isChecked ? "Moves it back to To buy" : "Moves it to In the cart")
    }
}
