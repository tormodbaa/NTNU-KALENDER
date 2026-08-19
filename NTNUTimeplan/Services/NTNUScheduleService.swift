import Foundation

/// Henter emnekatalog og timeplandata fra NTNUs udokumenterte, men åpne,
/// Liferay-portlet-endepunkter (samme kilde som github.com/adamcik/plan bruker).
/// Ingen autentisering kreves. Endepunktene kan endre seg uten varsel — derfor er
/// all parsing best-effort og feiler aldri katastrofalt (ukjente felt ignoreres).
actor NTNUScheduleService {
    static let shared = NTNUScheduleService()

    enum ServiceError: Error, LocalizedError {
        case badResponse
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .badResponse: "Fikk ikke svar fra NTNUs emnesider."
            case .decodingFailed: "Klarte ikke å tolke svaret fra NTNUs emnesider."
            }
        }
    }

    private let session: URLSession
    private let cacheURL: URL
    private var memoryCatalog: [CourseListing]?

    init(session: URLSession = .shared) {
        self.session = session
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        self.cacheURL = (dir ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("ntnu_course_catalog.json")
    }

    // MARK: - Emnekatalog (bulk-hentet, cachet lokalt for raskt lokalt søk)

    struct CatalogCache: Codable {
        let fetchedAt: Date
        let semesterKey: String
        let courses: [CourseListing]
    }

    /// Returnerer cachet katalog om den finnes og er fersk nok, ellers henter på nytt.
    func catalog(forceRefresh: Bool = false) async throws -> [CourseListing] {
        let semester = NTNUSemester.current()

        if !forceRefresh, let cached = loadCache(), cached.semesterKey == semester.artermin {
            memoryCatalog = cached.courses
            return cached.courses
        }
        if let memoryCatalog, !forceRefresh { return memoryCatalog }

        let fresh = try await fetchFullCatalog(semester: semester)
        memoryCatalog = fresh
        saveCache(CatalogCache(fetchedAt: .init(), semesterKey: semester.artermin, courses: fresh))
        return fresh
    }

    nonisolated func search(_ query: String, in courses: [CourseListing]) -> [CourseListing] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "nb_NO"))
        return courses.filter {
            $0.code.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "nb_NO")).contains(needle)
                || $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "nb_NO")).contains(needle)
        }
        .sorted { lhs, rhs in
            let lhsStarts = lhs.code.lowercased().hasPrefix(needle)
            let rhsStarts = rhs.code.lowercased().hasPrefix(needle)
            if lhsStarts != rhsStarts { return lhsStarts }
            return lhs.code < rhs.code
        }
    }

    private func fetchFullCatalog(semester: NTNUSemester) async throws -> [CourseListing] {
        var url = URLComponents(string: "https://www.ntnu.no/web/studier/emnesok")!
        url.queryItems = [
            .init(name: "p_p_id", value: "courselistportlet_WAR_courselistportlet"),
            .init(name: "p_p_lifecycle", value: "2"),
            .init(name: "p_p_mode", value: "view"),
            .init(name: "p_p_resource_id", value: "fetch-courselist-as-json"),
        ]

        var results: [CourseListing] = []
        var pageNo = 1
        let maxPages = 20

        while pageNo <= maxPages {
            var request = URLRequest(url: url.url!)
            request.httpMethod = "POST"
            request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            var body = [
                "english": "0",
                "pageNo": "\(pageNo)",
                "semester": "\(semester.searchYear)",
                "sortOrder": "+title",
                "trondheim": "1",
            ]
            body[semester.isFall ? "courseAutumn" : "courseSpring"] = "1"
            request.httpBody = body
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }
                .joined(separator: "&")
                .data(using: .utf8)

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw ServiceError.badResponse
            }

            let pageResult = try JSONDecoder().decode(RawCourseSearchResponse.self, from: data)
            let listings = pageResult.courses.map {
                CourseListing(code: $0.courseCode, name: $0.courseName, version: $0.courseVersion, location: $0.location)
            }
            results.append(contentsOf: listings)
            if listings.isEmpty || pageResult.hasMoreResults == false { break }
            pageNo += 1
        }
        return results
    }

    // MARK: - Timeplan per emne

    func fetchEvents(for course: SelectedCourse, version: String = "1") async throws -> [ScheduleEvent] {
        let semester = NTNUSemester.current()

        var url = URLComponents(string: "https://www.ntnu.no/web/studier/emner")!
        url.queryItems = [
            .init(name: "p_p_id", value: "coursedetailsportlet_WAR_courselistportlet"),
            .init(name: "p_p_lifecycle", value: "2"),
            .init(name: "p_p_mode", value: "view"),
            .init(name: "p_p_resource_id", value: "schedules"),
            .init(name: "_coursedetailsportlet_WAR_courselistportlet_year", value: "\(semester.year)"),
            .init(name: "_coursedetailsportlet_WAR_courselistportlet_courseCode", value: course.code),
            .init(name: "year", value: "\(semester.year)"),
            .init(name: "version", value: version),
        ]

        var request = URLRequest(url: url.url!)
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(RawScheduleResponse.self, from: data)
        return decoded.schedules
            .filter { $0.artermin == semester.artermin && $0.status == "active" }
            .compactMap { raw -> ScheduleEvent? in
                let start = Date(timeIntervalSince1970: Double(raw.from) / 1000)
                let end = Date(timeIntervalSince1970: Double(raw.to) / 1000)
                guard end > start else { return nil }

                let rooms = raw.rooms.map { room -> Room in
                    Room(
                        name: (room.room?.isEmpty == false ? room.room! : room.building) ?? "Ukjent rom",
                        building: room.building,
                        mazeMapURL: room.url.flatMap(URL.init(string:))
                    )
                }

                return ScheduleEvent(
                    id: "\(raw.activityCode)_\(raw.from)",
                    courseCode: course.code,
                    title: raw.title.isEmpty ? raw.name : raw.title,
                    kind: .classify(acronym: raw.acronym, name: raw.name, title: raw.title),
                    start: start,
                    end: end,
                    rooms: rooms,
                    week: raw.week,
                    studyProgramKeys: raw.studyProgramKeys ?? []
                )
            }
    }

    // MARK: - Disk-cache

    private func loadCache() -> CatalogCache? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CatalogCache.self, from: data)
    }

    private func saveCache(_ cache: CatalogCache) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}

// MARK: - Rå API-responser (kun feltene vi faktisk bruker; ukjente felt ignoreres av Codable)

private struct RawCourseSearchResponse: Decodable {
    let courses: [RawCourseListing]
    let hasMoreResults: Bool
}

private struct RawCourseListing: Decodable {
    let courseCode: String
    let courseName: String
    let courseVersion: String
    let location: String
}

private struct RawScheduleResponse: Decodable {
    let schedules: [RawScheduleActivity]
}

private struct RawScheduleActivity: Decodable {
    let acronym: String
    let activityCode: String
    let artermin: String
    let name: String
    let title: String
    let from: Int64
    let to: Int64
    let week: Int
    let rooms: [RawRoom]
    let status: String
    let studyProgramKeys: [String]?
}

private struct RawRoom: Decodable {
    let building: String?
    let room: String?
    let url: String?
}
