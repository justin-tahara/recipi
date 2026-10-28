import RecipiKit
import SwiftData
import SwiftUI

struct GroceryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.createdAt) private var items: [GroceryItem]

    @State private var newItemText = ""
    @State private var remindersMessage: String?
    @State private var isSendingToReminders = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Add an item", text: $newItemText)
                        .onSubmit(addItem)
                        .submitLabel(.done)
                }

                Section {
                    ForEach(items) { item in
                        GroceryRow(item: item)
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Send to Reminders", systemImage: "checklist") {
                            Task { await sendToReminders() }
                        }
                        .disabled(uncheckedItems.isEmpty || isSendingToReminders)

                        Button("Clear checked items", systemImage: "trash", role: .destructive, action: clearChecked)
                            .disabled(!items.contains(where: \.isChecked))
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

    private var uncheckedItems: [GroceryItem] {
        items.filter { !$0.isChecked }
    }

    private func addItem() {
        let text = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        modelContext.insert(GroceryItem(text: text))
        newItemText = ""
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private func clearChecked() {
        for item in items where item.isChecked {
            modelContext.delete(item)
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

private struct GroceryRow: View {
    @Bindable var item: GroceryItem

    var body: some View {
        Button {
            item.isChecked.toggle()
        } label: {
            HStack {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading) {
                    Text(item.text)
                        .strikethrough(item.isChecked)
                    if let recipeTitle = item.recipeTitle {
                        Text(recipeTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
