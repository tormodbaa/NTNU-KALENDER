import Foundation

/// Ett studieprogram slik det listes i NTNUs samlede studieoversikt (bulk-hentet
/// og cachet lokalt, akkurat som `CourseListing`).
struct StudyProgramListing: Identifiable, Codable, Hashable {
    let code: String
    let name: String
    let studyLevel: String

    var id: String { code }
}

/// Ett emne slik det listes i en studieplan for et studieprogram/kull.
struct StudyPlanCourse: Identifiable, Hashable {
    let code: String
    let name: String
    let isObligatory: Bool
    var id: String { code }
}

/// En gruppe emner innenfor én studieperiode (semester), enten den felles
/// kjernen eller en valgfri studieretning man må velge blant.
struct StudyPlanGroup: Identifiable {
    let label: String
    let courses: [StudyPlanCourse]
    var id: String { label }
}

struct StudyPlanPeriod: Identifiable {
    let periodNumber: Int
    let groups: [StudyPlanGroup]
    var id: Int { periodNumber }
}

struct StudyPlan {
    let code: String
    let name: String
    let year: Int
    let periods: [StudyPlanPeriod]
}
