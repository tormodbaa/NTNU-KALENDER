import Foundation

/// NTNU opererer med to semestre i året. Høst starter i juli (opptak/emnesider åpner
/// tidlig), vår i januar. Grensen 1. juli er den samme heuristikken `adamcik/plan` bruker.
struct NTNUSemester: Hashable {
    let year: Int
    let isFall: Bool

    static func current(referenceDate: Date = .init()) -> NTNUSemester {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: referenceDate)
        let year = components.year ?? 2026
        let month = components.month ?? 1
        return NTNUSemester(year: year, isFall: month >= 7)
    }

    /// Slik NTNUs "artermin"-felt på schedule-objekter er formatert, f.eks. "2026_HØST".
    var artermin: String { "\(year)_\(isFall ? "HØST" : "VÅR")" }

    /// Året som brukes i `courselistportlet`-søket: vårsemesteret bruker forrige årstall.
    var searchYear: Int { isFall ? year : year - 1 }
}
