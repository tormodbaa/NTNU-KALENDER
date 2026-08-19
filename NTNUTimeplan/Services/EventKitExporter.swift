import EventKit
import Foundation
import SwiftUI

/// Eksporterer valgte timeplanhendelser til en dedikert "NTNU Timeplan"-kalender i
/// Apple Kalender via EventKit, slik at brukeren kan slette den samlet igjen senere.
final class EventKitExporter {
    enum ExportError: Error, LocalizedError {
        case accessDenied
        case calendarUnavailable

        var errorDescription: String? {
            switch self {
            case .accessDenied: "Fikk ikke tilgang til Kalender. Gi tilgang i Innstillinger."
            case .calendarUnavailable: "Fant ingen kalenderkilde å lagre i."
            }
        }
    }

    private let store = EKEventStore()
    private static let calendarTitle = "NTNU Timeplan"

    func requestAccess() async throws {
        let granted = try await store.requestFullAccessToEvents()
        guard granted else { throw ExportError.accessDenied }
    }

    /// Fjerner tidligere eksporterte hendelser i appens egen kalender og legger inn
    /// de gjeldende, slik at et nytt eksport-trykk alltid gir en ren, oppdatert timeplan.
    func replaceEvents(with events: [ScheduleEvent], courses: [SelectedCourse]) throws {
        let calendar = try appCalendar()
        let nameByCode = Dictionary(uniqueKeysWithValues: courses.map { ($0.code, $0.name) })
        let colorByCode = Dictionary(uniqueKeysWithValues: courses.map { ($0.code, $0.color) })

        let existingPredicate = store.predicateForEvents(
            withStart: .distantPast,
            end: .distantFuture,
            calendars: [calendar]
        )
        for existing in store.events(matching: existingPredicate) {
            try? store.remove(existing, span: .thisEvent, commit: false)
        }

        for event in events {
            let ekEvent = EKEvent(eventStore: store)
            ekEvent.calendar = calendar
            let courseName = nameByCode[event.courseCode] ?? ""
            ekEvent.title = "\(event.courseCode) \(courseName) – \(event.title)"
            ekEvent.startDate = event.start
            ekEvent.endDate = event.end
            ekEvent.location = event.rooms.map(\.displayName).joined(separator: ", ")
            ekEvent.notes = nameByCode[event.courseCode]
            _ = colorByCode[event.courseCode]
            try? store.save(ekEvent, span: .thisEvent, commit: false)
        }

        try store.commit()
    }

    private func appCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == Self.calendarTitle }) {
            return existing
        }
        guard let source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first(where: { $0.sourceType == .local })
            ?? store.sources.first
        else {
            throw ExportError.calendarUnavailable
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        calendar.source = source
        calendar.cgColor = CourseColor.blue.color.cgColor
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }
}
