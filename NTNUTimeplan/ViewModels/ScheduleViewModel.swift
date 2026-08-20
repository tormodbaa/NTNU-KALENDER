import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published private(set) var timeplaner: [Timeplan] = []
    @Published private(set) var activeTimeplanID: Timeplan.ID
    @Published private(set) var events: [ScheduleEvent] = []
    @Published private(set) var conflictingEventIDs: Set<String> = []

    @Published var searchQuery: String = "" { didSet { runSearch() } }
    @Published private(set) var searchResults: [CourseListing] = []

    @Published private(set) var isLoadingCatalog = false
    @Published private(set) var isLoadingEvents = false
    @Published var errorMessage: String?
    @Published private(set) var usingDemoData = false

    @Published var notificationsEnabled = false {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Self.notificationsEnabledKey) }
    }
    @Published var notificationLeadMinutes = 15 {
        didSet { UserDefaults.standard.set(notificationLeadMinutes, forKey: Self.notificationLeadKey) }
    }
    /// `true` når iOS har blokkert varsler for appen (typisk fordi brukeren svarte nei
    /// på systemdialogen en gang tidligere — iOS spør bare én gang, så etterpå må
    /// varsler skrus på manuelt i Innstillinger-appen). Uten dette flagget ser
    /// varslingsbryteren ut til å ikke gjøre noe når man trykker på den.
    @Published private(set) var notificationPermissionDenied = false
    /// Emner brukeren har skrudd AV varsler for (opt-out — nye emner varsles som
    /// standard, uten at brukeren må huske å skru dem på hver gang).
    @Published private(set) var mutedCourseCodes: Set<String> = []
    /// Hendelsestyper (forelesning/øving/lab/…) brukeren har skrudd av varsler for,
    /// f.eks. slik at man kan velge å bare varsles om forelesninger, ikke mattelab.
    @Published private(set) var mutedEventKinds: Set<EventKind> = []

    /// Emner med mange studieprogram registrerer ofte flere parallelle grupper (ulikt
    /// rom/tidspunkt) som separate aktiviteter i NTNUs data. Uten å vite hvilket
    /// studieprogram brukeren faktisk går på, kan vi ikke skille "min gruppe" fra andres —
    /// da vises alle gruppene og de ser ut som kolliderende timer. Se `myStudyProgramCode`.
    @Published private(set) var myStudyProgram: StudyProgramListing?

    private let service = NTNUScheduleService.shared
    private var catalog: [CourseListing] = []
    private var eventsCache: [Timeplan.ID: [ScheduleEvent]] = [:]

    private static let timeplanerKey = "ntnu.timeplan.timeplaner.v2"
    private static let activeIDKey = "ntnu.timeplan.activeID.v2"
    private static let notificationsEnabledKey = "ntnu.timeplan.notificationsEnabled"
    private static let notificationLeadKey = "ntnu.timeplan.notificationLeadMinutes"
    private static let myStudyProgramKey = "ntnu.timeplan.myStudyProgram"
    private static let mutedCourseCodesKey = "ntnu.timeplan.mutedCourseCodes"
    private static let mutedEventKindsKey = "ntnu.timeplan.mutedEventKinds"

    private var myStudyProgramCode: String? { myStudyProgram?.code }

    var activeTimeplan: Timeplan {
        timeplaner.first(where: { $0.id == activeTimeplanID }) ?? timeplaner[0]
    }

    var selectedCourses: [SelectedCourse] { activeTimeplan.courses }

    init() {
        let loaded = Self.loadPersistedTimeplaner()
        timeplaner = loaded.timeplaner
        activeTimeplanID = loaded.activeID
        notificationsEnabled = UserDefaults.standard.bool(forKey: Self.notificationsEnabledKey)
        let storedLead = UserDefaults.standard.integer(forKey: Self.notificationLeadKey)
        notificationLeadMinutes = storedLead == 0 ? 15 : storedLead
        if let data = UserDefaults.standard.data(forKey: Self.myStudyProgramKey) {
            myStudyProgram = try? JSONDecoder().decode(StudyProgramListing.self, from: data)
        }
        if let codes = UserDefaults.standard.array(forKey: Self.mutedCourseCodesKey) as? [String] {
            mutedCourseCodes = Set(codes)
        }
        if let kindsData = UserDefaults.standard.data(forKey: Self.mutedEventKindsKey),
           let kinds = try? JSONDecoder().decode([EventKind].self, from: kindsData) {
            mutedEventKinds = Set(kinds)
        }
    }

    // MARK: - Mitt studieprogram (for å filtrere bort parallellgrupper som ikke gjelder deg)

    func setMyStudyProgram(_ program: StudyProgramListing?) async {
        myStudyProgram = program
        if let program, let data = try? JSONEncoder().encode(program) {
            UserDefaults.standard.set(data, forKey: Self.myStudyProgramKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.myStudyProgramKey)
        }
        await refreshAllEvents()
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

    // MARK: - Kalendere (Timeplaner)

    func selectTimeplan(_ id: Timeplan.ID) {
        guard id != activeTimeplanID, timeplaner.contains(where: { $0.id == id }) else { return }
        activeTimeplanID = id
        persistTimeplaner()
        if let cached = eventsCache[id] {
            events = cached
            usingDemoData = false
            recomputeConflicts()
        } else {
            events = []
            Task { await refreshAllEvents() }
        }
    }

    func createTimeplan(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newPlan = Timeplan(name: trimmed.isEmpty ? "Ny kalender" : trimmed)
        timeplaner.append(newPlan)
        activeTimeplanID = newPlan.id
        events = []
        persistTimeplaner()
    }

    func renameTimeplan(_ id: Timeplan.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = timeplaner.firstIndex(where: { $0.id == id }) else { return }
        timeplaner[index].name = trimmed
        persistTimeplaner()
    }

    func deleteTimeplan(_ id: Timeplan.ID) {
        guard timeplaner.count > 1 else { return }
        timeplaner.removeAll { $0.id == id }
        eventsCache[id] = nil
        if activeTimeplanID == id {
            activeTimeplanID = timeplaner[0].id
            events = eventsCache[activeTimeplanID] ?? []
            if events.isEmpty { Task { await refreshAllEvents() } }
        }
        persistTimeplaner()
    }

    // MARK: - Valgte emner (i aktiv kalender)

    var isSelected: (String) -> Bool {
        { [selectedCourses] code in selectedCourses.contains { $0.code == code } }
    }

    func addCourse(_ listing: CourseListing) {
        guard let index = timeplaner.firstIndex(where: { $0.id == activeTimeplanID }) else { return }
        guard !timeplaner[index].courses.contains(where: { $0.code == listing.code }) else { return }
        let usedColors = Set(timeplaner[index].courses.map(\.color))
        let course = SelectedCourse(code: listing.code, name: listing.name, color: .next(excluding: usedColors))
        timeplaner[index].courses.append(course)
        persistTimeplaner()
        Task { await fetchEvents(for: course) }
    }

    /// Legger til flere emner samlet (f.eks. fra en studieretning) og henter timeplandata for alle i ett steg.
    func addCourses(_ listings: [CourseListing]) async {
        guard let index = timeplaner.firstIndex(where: { $0.id == activeTimeplanID }) else { return }
        var usedColors = Set(timeplaner[index].courses.map(\.color))
        var added: [SelectedCourse] = []
        for listing in listings where !timeplaner[index].courses.contains(where: { $0.code == listing.code }) {
            let color = CourseColor.next(excluding: usedColors)
            usedColors.insert(color)
            let course = SelectedCourse(code: listing.code, name: listing.name, color: color)
            timeplaner[index].courses.append(course)
            added.append(course)
        }
        guard !added.isEmpty else { return }
        persistTimeplaner()
        await refreshAllEvents()
    }

    // MARK: - Studieretning-import

    func loadProgramCatalog() async throws -> [StudyProgramListing] {
        try await service.programCatalog()
    }

    func searchPrograms(_ query: String, in programs: [StudyProgramListing]) -> [StudyProgramListing] {
        service.searchPrograms(query, in: programs)
    }

    func fetchStudyPlanYears(programCode: String) async throws -> [Int] {
        try await service.fetchStudyPlanYears(programCode: programCode)
    }

    func fetchStudyPlan(programCode: String, year: Int) async throws -> StudyPlan {
        try await service.fetchStudyPlan(programCode: programCode, year: year)
    }

    /// Legger til emner fra en hentet studieplan (se `StudyProgramImportView`).
    func addStudyPlanCourses(_ courses: [StudyPlanCourse]) async {
        guard let index = timeplaner.firstIndex(where: { $0.id == activeTimeplanID }) else { return }
        var usedColors = Set(timeplaner[index].courses.map(\.color))
        var addedAny = false
        for course in courses where !timeplaner[index].courses.contains(where: { $0.code == course.code }) {
            let color = CourseColor.next(excluding: usedColors)
            usedColors.insert(color)
            timeplaner[index].courses.append(SelectedCourse(code: course.code, name: course.name, color: color))
            addedAny = true
        }
        guard addedAny else { return }
        persistTimeplaner()
        await refreshAllEvents()
    }

    func removeCourse(_ code: String) {
        guard let index = timeplaner.firstIndex(where: { $0.id == activeTimeplanID }) else { return }
        timeplaner[index].courses.removeAll { $0.code == code }
        events.removeAll { $0.courseCode == code }
        eventsCache[activeTimeplanID] = events
        persistTimeplaner()
        recomputeConflicts()
        Task { await rescheduleNotificationsIfNeeded() }
    }

    func removeAllCourses() {
        guard let index = timeplaner.firstIndex(where: { $0.id == activeTimeplanID }) else { return }
        timeplaner[index].courses.removeAll()
        events.removeAll()
        eventsCache[activeTimeplanID] = []
        persistTimeplaner()
        recomputeConflicts()
        Task { await rescheduleNotificationsIfNeeded() }
    }

    func refreshAllEvents() async {
        let courses = selectedCourses
        guard !courses.isEmpty else {
            events = []
            eventsCache[activeTimeplanID] = []
            return
        }
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        events = []
        usingDemoData = false
        var anyFailed = false
        for course in courses {
            do {
                let fetched = try await service.fetchEvents(for: course, programCode: myStudyProgramCode)
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
        eventsCache[activeTimeplanID] = events
        recomputeConflicts()
        await rescheduleNotificationsIfNeeded()
    }

    private func fetchEvents(for course: SelectedCourse) async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            let fetched = try await service.fetchEvents(for: course, programCode: myStudyProgramCode)
            events.append(contentsOf: fetched)
            eventsCache[activeTimeplanID] = events
            recomputeConflicts()
            await rescheduleNotificationsIfNeeded()
        } catch {
            errorMessage = "Klarte ikke å hente timeplan for \(course.code)."
        }
    }

    // MARK: - Varslinger

    func setNotificationsEnabled(_ enabled: Bool) async {
        guard enabled else {
            notificationsEnabled = false
            NotificationScheduler.cancelAll()
            return
        }

        // iOS spør kun én gang via systemdialogen. Hvis brukeren allerede har svart
        // nei (eller appen ble installert på nytt etter et avslag), vil et nytt kall
        // til requestAuthorization aldri vise dialogen igjen — den svarer bare "denied"
        // stille. Sjekk status først, slik at vi kan forklare hva som skjer i stedet
        // for at bryteren bare ser ut til å ikke reagere på trykk.
        switch await NotificationScheduler.authorizationStatus() {
        case .denied:
            notificationsEnabled = false
            notificationPermissionDenied = true
            errorMessage = "Varsler er blokkert for appen i iOS. Trykk \"Åpne Innstillinger\" og skru dem på der."
        case .authorized, .provisional, .ephemeral:
            notificationsEnabled = true
            notificationPermissionDenied = false
            await rescheduleNotificationsIfNeeded()
        default:
            let granted = await NotificationScheduler.requestAuthorization()
            notificationsEnabled = granted
            notificationPermissionDenied = !granted
            if granted {
                await rescheduleNotificationsIfNeeded()
            } else {
                errorMessage = "Fikk ikke tilgang til varsler."
            }
        }
    }

    /// Kalles når Innstillinger-visningen åpnes, i tilfelle brukeren har vært innom
    /// iOS' Innstillinger-app og endret varslingstillatelsen der siden sist.
    func refreshNotificationPermissionStatus() async {
        let status = await NotificationScheduler.authorizationStatus()
        notificationPermissionDenied = status == .denied
        if status == .denied, notificationsEnabled {
            notificationsEnabled = false
        }
    }

    func updateNotificationLeadMinutes(_ minutes: Int) async {
        notificationLeadMinutes = minutes
        await rescheduleNotificationsIfNeeded()
    }

    func setCourseMuted(_ code: String, muted: Bool) async {
        if muted {
            mutedCourseCodes.insert(code)
        } else {
            mutedCourseCodes.remove(code)
        }
        UserDefaults.standard.set(Array(mutedCourseCodes), forKey: Self.mutedCourseCodesKey)
        await rescheduleNotificationsIfNeeded()
    }

    func setKindMuted(_ kind: EventKind, muted: Bool) async {
        if muted {
            mutedEventKinds.insert(kind)
        } else {
            mutedEventKinds.remove(kind)
        }
        if let data = try? JSONEncoder().encode(mutedEventKinds) {
            UserDefaults.standard.set(data, forKey: Self.mutedEventKindsKey)
        }
        await rescheduleNotificationsIfNeeded()
    }

    private func rescheduleNotificationsIfNeeded() async {
        guard notificationsEnabled else { return }
        await NotificationScheduler.reschedule(
            events: events,
            courses: selectedCourses,
            leadMinutes: notificationLeadMinutes,
            mutedCourseCodes: mutedCourseCodes,
            mutedKinds: mutedEventKinds
        )
    }

    // MARK: - Kollisjonsdeteksjon

    private func recomputeConflicts() {
        var conflicts: Set<String> = []
        // Lange "åpne" økter (se `ScheduleEvent.isExtendedSession`) er tilgjengelighetsvinduer,
        // ikke sammenhengende obligatorisk tid — de skal ikke telle som kollisjon med noe.
        let sorted = events.filter { !$0.isExtendedSession }.sorted { $0.start < $1.start }
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

    private func persistTimeplaner() {
        guard let data = try? JSONEncoder().encode(timeplaner) else { return }
        UserDefaults.standard.set(data, forKey: Self.timeplanerKey)
        UserDefaults.standard.set(activeTimeplanID.uuidString, forKey: Self.activeIDKey)
    }

    private static func loadPersistedTimeplaner() -> (timeplaner: [Timeplan], activeID: Timeplan.ID) {
        guard let data = UserDefaults.standard.data(forKey: timeplanerKey),
              let decoded = try? JSONDecoder().decode([Timeplan].self, from: data),
              !decoded.isEmpty
        else {
            let initial = Timeplan(name: "Min timeplan")
            return ([initial], initial.id)
        }
        let activeID = UserDefaults.standard.string(forKey: activeIDKey).flatMap(UUID.init)
        let resolvedID = decoded.first(where: { $0.id == activeID })?.id ?? decoded[0].id
        return (decoded, resolvedID)
    }
}
