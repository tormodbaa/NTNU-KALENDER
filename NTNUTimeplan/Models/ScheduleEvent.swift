import Foundation

enum EventKind: String, Codable, CaseIterable {
    case lecture, exercise, lab, seminar, exam, other

    /// NTNUs "acronym"/"name"/"title"-felter er fritekst på norsk. Vi grovklassifiserer
    /// dem for ikoner/filtrering; selve tittelen fra API-et vises fortsatt uendret i UI.
    static func classify(acronym: String, name: String, title: String) -> EventKind {
        let text = "\(acronym) \(name) \(title)".lowercased()
        if text.contains("eksamen") { return .exam }
        if text.contains("øving") || text.contains("oving") || text.contains("lab") { return .lab }
        if text.contains("forelesning") || text.contains("form") { return .lecture }
        if text.contains("seminar") || text.contains("gruppe") || text.contains("kollokv") { return .seminar }
        return .other
    }

    var shortLabel: String {
        switch self {
        case .lecture: "Forelesning"
        case .exercise: "Øving"
        case .lab: "Lab/øving"
        case .seminar: "Seminar"
        case .exam: "Eksamen"
        case .other: "Annet"
        }
    }

    var symbolName: String {
        switch self {
        case .lecture: "person.wave.2.fill"
        case .exercise, .lab: "pencil.and.ruler.fill"
        case .seminar: "person.3.fill"
        case .exam: "graduationcap.fill"
        case .other: "calendar"
        }
    }
}

/// Én konkret undervisningshendelse på en gitt dato, hentet fra NTNUs
/// `coursedetailsportlet` schedules-endepunkt. Modellen representerer en faktisk
/// forekomst (ikke et gjentakelsesmønster), slik at avvik/hull i undervisningsuker
/// blir riktige uten egen unntakshåndtering.
struct ScheduleEvent: Identifiable, Codable, Hashable {
    let id: String
    let courseCode: String
    var title: String
    var kind: EventKind
    var start: Date
    var end: Date
    var rooms: [Room]
    var week: Int
    var studyProgramKeys: [String]

    var isValid: Bool { end > start }
}
