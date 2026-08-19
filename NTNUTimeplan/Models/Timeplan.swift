import Foundation

/// En navngitt samling av valgte emner. Brukeren kan holde flere separate
/// timeplaner (f.eks. "Høst 2026" og "Backup-fag") og bytte mellom dem.
struct Timeplan: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var courses: [SelectedCourse]

    init(id: UUID = UUID(), name: String, courses: [SelectedCourse] = []) {
        self.id = id
        self.name = name
        self.courses = courses
    }
}
