import Foundation

struct Room: Codable, Hashable {
    var name: String
    var building: String?
    var mazeMapURL: URL?

    var displayName: String {
        guard let building, !building.isEmpty, building != name else { return name }
        return "\(name), \(building)"
    }
}
