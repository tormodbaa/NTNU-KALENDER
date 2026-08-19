import Foundation

/// Genererer en RFC 5545 .ics-fil av valgte timeplanhendelser, til bruk i delingsarket
/// eller for import i andre kalenderapper enn Apples.
enum ICSExporter {
    static func makeICS(events: [ScheduleEvent], courses: [SelectedCourse]) -> String {
        let nameByCode = Dictionary(uniqueKeysWithValues: courses.map { ($0.code, $0.name) })
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//NTNUTimeplan//Prototype//NB",
            "CALSCALE:GREGORIAN",
        ]

        for event in events.sorted(by: { $0.start < $1.start }) {
            let courseName = nameByCode[event.courseCode] ?? event.courseCode
            lines.append(contentsOf: [
                "BEGIN:VEVENT",
                "UID:\(event.id)@ntnu-timeplan-prototype",
                "DTSTAMP:\(formatter.string(from: .init()))",
                "DTSTART:\(formatter.string(from: event.start))",
                "DTEND:\(formatter.string(from: event.end))",
                "SUMMARY:\(escape("\(event.courseCode) – \(event.title)"))",
                "DESCRIPTION:\(escape(courseName))",
                "LOCATION:\(escape(event.rooms.map(\.displayName).joined(separator: ", ")))",
                "END:VEVENT",
            ])
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n")
    }

    /// Skriver .ics-innholdet til en midlertidig fil og returnerer URL-en, klar for
    /// UIActivityViewController (delingsark).
    static func writeTemporaryFile(events: [ScheduleEvent], courses: [SelectedCourse]) throws -> URL {
        let content = makeICS(events: events, courses: courses)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ntnu-timeplan.ics")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
