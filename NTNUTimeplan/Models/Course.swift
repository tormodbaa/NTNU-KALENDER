import SwiftUI

/// Et emne slik det vises i NTNUs emnesøk-katalog (bulk-hentet og cachet lokalt).
struct CourseListing: Identifiable, Codable, Hashable {
    let code: String
    let name: String
    let version: String
    let location: String

    var id: String { code }
}

/// Et emne brukeren har valgt inn i sin timeplan.
struct SelectedCourse: Identifiable, Codable, Hashable {
    let code: String
    var name: String
    var color: CourseColor

    var id: String { code }
}

enum CourseColor: String, Codable, CaseIterable, Hashable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }

    /// Deterministisk, men jevnt fordelt rekkefølge slik at nye emner får ulik farge.
    static func next(excluding used: Set<CourseColor>) -> CourseColor {
        allCases.first(where: { !used.contains($0) }) ?? allCases.randomElement()!
    }
}
