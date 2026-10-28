import EventKit
import Foundation

/// Pushes grocery items into a Reminders list, creating the list the first
/// time. Everything happens on one local EKEventStore inside a nonisolated
/// function, so no non-Sendable EventKit object crosses actors.
enum RemindersExporter {
    enum ExportError: LocalizedError {
        case accessDenied
        case noRemindersAccount

        var errorDescription: String? {
            switch self {
            case .accessDenied: "recipi needs access to Reminders. You can allow it in Settings."
            case .noRemindersAccount: "There's no Reminders account on this device to add the list to."
            }
        }
    }

    static func export(_ items: [String], toListNamed listName: String) async throws -> Int {
        let store = EKEventStore()
        guard try await store.requestFullAccessToReminders() else {
            throw ExportError.accessDenied
        }
        let list = try reminderList(named: listName, in: store)
        for item in items {
            let reminder = EKReminder(eventStore: store)
            reminder.title = item
            reminder.calendar = list
            try store.save(reminder, commit: false)
        }
        try store.commit()
        return items.count
    }

    private static func reminderList(named name: String, in store: EKEventStore) throws -> EKCalendar {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == name }) {
            return existing
        }
        guard let source = store.defaultCalendarForNewReminders()?.source else {
            throw ExportError.noRemindersAccount
        }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = name
        list.source = source
        try store.saveCalendar(list, commit: true)
        return list
    }
}
