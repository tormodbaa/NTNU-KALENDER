import SwiftUI

/// Lar brukeren søke opp studieprogrammet sitt (navn eller kode), velge kull/opptaksår,
/// og krysse av hvilke emner fra studieplanen som skal legges til i aktiv kalender.
struct StudyProgramImportView: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProgram: StudyProgramListing?

    var body: some View {
        NavigationStack {
            Group {
                if let selectedProgram {
                    StudyProgramPlanPicker(program: selectedProgram) {
                        self.selectedProgram = nil
                    }
                } else {
                    StudyProgramSearchList { program in
                        selectedProgram = program
                    }
                }
            }
            .navigationTitle("Legg til studieretning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
    }
}

/// Steg 1: søk opp studieprogrammet blant NTNUs ~400 programmer.
private struct StudyProgramSearchList: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    let onSelect: (StudyProgramListing) -> Void

    @State private var query = ""
    @State private var catalog: [StudyProgramListing] = []
    @State private var isLoadingCatalog = false
    @State private var errorMessage: String?

    private var results: [StudyProgramListing] {
        viewModel.searchPrograms(query, in: catalog)
    }

    var body: some View {
        List {
            Section {
                if isLoadingCatalog {
                    HStack {
                        ProgressView()
                        Text("Henter studieprogrammer fra NTNU …").foregroundStyle(.secondary)
                    }
                } else if !query.isEmpty && results.isEmpty {
                    Text("Ingen studieprogram funnet for \"\(query)\".").foregroundStyle(.secondary)
                }

                ForEach(results) { program in
                    Button {
                        onSelect(program)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(program.name).font(.subheadline.weight(.semibold))
                            Text("\(program.code) · \(program.studyLevel)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.orange)
                }
            }
        }
        .searchable(text: $query, prompt: "Studieprogram, f.eks. Datateknologi eller MTDT")
        .task { await loadCatalog() }
    }

    private func loadCatalog() async {
        guard catalog.isEmpty else { return }
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }
        do {
            catalog = try await viewModel.loadProgramCatalog()
        } catch {
            errorMessage = "Fant ikke listen over studieprogrammer akkurat nå. Prøv igjen om litt."
        }
    }
}

/// Steg 2: velg kull/opptaksår for det valgte programmet, og kryss av emner fra studieplanen.
private struct StudyProgramPlanPicker: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    let program: StudyProgramListing
    let onChangeProgram: () -> Void

    @State private var years: [Int] = []
    @State private var selectedYear: Int?
    @State private var plan: StudyPlan?
    @State private var selectedCourseCodes: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button("Bytt studieprogram", systemImage: "arrow.left", action: onChangeProgram)
                if !years.isEmpty {
                    Picker("Opptaksår", selection: yearBinding) {
                        ForEach(years, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text(program.name)
            } footer: {
                Text("\(program.code) · \(program.studyLevel)")
            }

            if let plan {
                ForEach(plan.periods) { period in
                    ForEach(period.groups) { group in
                        Section("Semester \(period.periodNumber) – \(group.label)") {
                            ForEach(group.courses) { course in
                                CourseToggleRow(
                                    course: course,
                                    isOn: selectedCourseCodes.contains(course.code)
                                ) { isOn in
                                    if isOn {
                                        selectedCourseCodes.insert(course.code)
                                    } else {
                                        selectedCourseCodes.remove(course.code)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.orange)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Legg til (\(selectedCourseCodes.count))") {
                    Task { await addSelected() }
                }
                .disabled(selectedCourseCodes.isEmpty)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task { await loadYears() }
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { selectedYear ?? years.first ?? 0 },
            set: { newValue in
                selectedYear = newValue
                Task { await loadPlan() }
            }
        )
    }

    private func loadYears() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            years = try await viewModel.fetchStudyPlanYears(programCode: program.code)
            selectedYear = years.first
            await loadPlan()
        } catch {
            errorMessage = "Fant ikke kullårene for \(program.name)."
        }
    }

    private func loadPlan() async {
        guard let year = selectedYear else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await viewModel.fetchStudyPlan(programCode: program.code, year: year)
            plan = fetched
            selectedCourseCodes = Set(
                fetched.periods
                    .flatMap(\.groups)
                    .filter { !$0.label.hasPrefix("Studieretning:") }
                    .flatMap(\.courses)
                    .filter(\.isObligatory)
                    .map(\.code)
            )
        } catch {
            errorMessage = "Klarte ikke å hente studieplanen for \(year)."
        }
    }

    private func addSelected() async {
        guard let plan else { return }
        let courses = plan.periods
            .flatMap(\.groups)
            .flatMap(\.courses)
            .filter { selectedCourseCodes.contains($0.code) }
        var seen = Set<String>()
        let deduplicated = courses.filter { seen.insert($0.code).inserted }
        await viewModel.addStudyPlanCourses(deduplicated)
        dismiss()
    }
}

private struct CourseToggleRow: View {
    let course: StudyPlanCourse
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: onChange)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(course.code) – \(course.name)")
                    .font(.subheadline)
                if course.isObligatory {
                    Text("Obligatorisk").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
