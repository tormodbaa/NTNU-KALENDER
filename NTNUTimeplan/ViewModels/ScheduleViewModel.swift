import Foundation
import SwiftUI

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published private(set) var selectedCourses: [SelectedCourse] = []
    @Published private(set) var events: [ScheduleEvent] = []
    @Published private(set) var conflictingEventIDs: Set<String> = []

    @Published var searchQuery: String = "" { didSet { runSearch() } }
    @Published private(set) var searchResults: [CourseListing] = []

    @Published private(set) var isLoadingCatalog = false
    @Published private(set) var isLoadingEvents = false
    @Published var errorMessage: String?
    @Published private(set) var usingDemoData = false

    private let service = NTNUScheduleService.shared
    private var catalog: [CourseListing] = []
    private static let storageKey = "ntnu.timeplan.selectedCourses"

    init() {
        selectedCourses = Self.loadPersistedCourses()
    }

    // MARK: - Katalog og søk

    func loadCatalogIfNeeded() async {
        guard catalog.isEmpty else { return }
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }
        do {
            catalog = try await service.catalog()
            errorMessage = nil
        } catch {
            errorMessage = "Fant ikke emnekatalogen fra NTNU akkurat nå. Prøv igjen om litt."
        }
        if !selectedCourses.isEmpty && events.isEmpty {
            await refreshAllEvents()
        }
    }

    private func runSearch() {
        searchResults = service.search(searchQuery, in: catalog)
    }

    // MARK: - Valgte emner

    var isSelected: (String) -> Bool {
        { [selectedCourses] code in selectedCourses.contains { $0.code == code } }
    }

    func addCourse(_ listing: CourseListing) {
        guard !selectedCourses.contains(where: { $0.code == listing.code }) else { return }
        let usedColors = Set(selectedCourses.map(\.color))
        let course = SelectedCourse(code: listing.code, name: listing.name, color: .next(excluding: usedColors))
        selectedCourses.append(course)
        persistSelectedCourses()
        Task { await fetchEvents(for: course) }
    }

    func removeCourse(_ code: String) {
        selectedCourses.removeAll { $0.code == code }
        events.removeAll { $0.courseCode == code }
        persistSelectedCourses()
        recomputeConflicts()
    }

    func refreshAllEvents() async {
        guard !selectedCourses.isEmpty else { return }
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        events = []
        usingDemoData = false
        var anyFailed = false
        for course in selectedCourses {
            do {
                let fetched = try await service.fetchEvents(for: course)
                events.append(contentsOf: fetched)
            } catch {
                anyFailed = true
            }
        }
        if anyFailed && events.isEmpty {
            events = MockData.events()
            usingDemoData = true
            errorMessage = "Klarte ikke å hente sanntidsdata fra NTNU. Viser demo-timeplan i stedet."
        } else {
            errorMessage = nil
        }
        recomputeConflicts()
    }

    private func fetchEvents(for course: SelectedCourse) async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            let fetched = try await service.fetchEvents(for: course)
            events.append(contentsOf: fetched)
            recomputeConflicts()
        } catch {
            errorMessage = "Klarte ikke å hente timeplan for \(course.code)."
        }
    }

    // MARK: - Kollisjonsdeteksjon

    private func recomputeConflicts() {
        var conflicts: Set<String> = []
        let sorted = events.sorted { $0.start < $1.start }
        for i in sorted.indices {
            for j in (i + 1)..<sorted.indices.upperBound where j != i {
                let a = sorted[i], b = sorted[j]
                if b.start >= a.end { break }
                if a.start < b.end && a.end > b.start {
                    conflicts.insert(a.id)
                    conflicts.insert(b.id)
                }
            }
        }
        conflictingEventIDs = conflicts
    }

    func hasConflict(_ event: ScheduleEvent) -> Bool {
        conflictingEventIDs.contains(event.id)
    }

    // MARK: - Persistens

    private func persistSelectedCourses() {
        guard let data = try? JSONEncoder().encode(selectedCourses) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private static func loadPersistedCourses() -> [SelectedCourse] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SelectedCourse].self, from: data)
        else { return [] }
        return decoded
    }
}
