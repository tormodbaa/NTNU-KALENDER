import Foundation

/// Statiske eksempeldata til SwiftUI-previews og til demo/offline-modus dersom
/// NTNU-endepunktene skulle slutte å svare.
enum MockData {
    static let courses: [SelectedCourse] = [
        SelectedCourse(code: "TDT4120", name: "Algoritmer og datastrukturer", color: .blue),
        SelectedCourse(code: "TMA4245", name: "Statistikk", color: .orange),
        SelectedCourse(code: "TDT4180", name: "Menneske-maskin-interaksjon", color: .green),
    ]

    static func events(referenceDate: Date = .init()) -> [ScheduleEvent] {
        let calendar = Calendar.ntnu
        let monday = referenceDate.mondayOfWeek()
        let week = monday.weekOfYear

        func event(_ course: SelectedCourse, day: Int, startHour: Int, startMinute: Int = 0, hours: Double, title: String, kind: EventKind, room: String, building: String) -> ScheduleEvent {
            let dayDate = calendar.date(byAdding: .day, value: day, to: monday)!
            let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: dayDate)!
            let end = start.addingTimeInterval(hours * 3600)
            return ScheduleEvent(
                id: UUID().uuidString,
                courseCode: course.code,
                title: title,
                kind: kind,
                start: start,
                end: end,
                rooms: [Room(name: room, building: building, mazeMapURL: nil)],
                week: week,
                studyProgramKeys: []
            )
        }

        let algdat = courses[0]
        let stats = courses[1]
        let mmi = courses[2]

        return [
            event(algdat, day: 0, startHour: 10, hours: 2, title: "Forelesning", kind: .lecture, room: "R7", building: "Realfagbygget"),
            event(algdat, day: 2, startHour: 14, hours: 1, title: "Øvingstime", kind: .exercise, room: "KJL4", building: "Kjelhuset"),
            event(stats, day: 0, startHour: 12, hours: 2, title: "Forelesning", kind: .lecture, room: "S1", building: "Sentralbygg 1"),
            event(stats, day: 3, startHour: 9, hours: 2, title: "Regneøving", kind: .exercise, room: "F1", building: "Hovedbygget"),
            event(mmi, day: 1, startHour: 10, hours: 2, title: "Forelesning", kind: .lecture, room: "R1", building: "Realfagbygget"),
            event(mmi, day: 1, startHour: 13, hours: 2, title: "Gruppearbeid", kind: .seminar, room: "IT-vest 121", building: "IT-bygget"),
            // Bevisst kollisjon for å vise kollisjonsvarsel i UI:
            event(mmi, day: 0, startHour: 11, hours: 1, title: "Lab", kind: .lab, room: "Lab 3", building: "IT-bygget"),
        ]
    }
}
