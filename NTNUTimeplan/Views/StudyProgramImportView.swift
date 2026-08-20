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
                        Section {
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
                        } header: {
                            SemesterSectionHeader(
                                title: "Semester \(period.periodNumber) – \(group.label)",
                                allSelected: isGroupFullySelected(group),
                                toggle: { toggleGroup(group) }
                            )
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

    private func isGroupFullySelected(_ group: StudyPlanGroup) -> Bool {
        !group.courses.isEmpty && group.courses.allSatisfy { selectedCourseCodes.contains($0.code) }
    }

    private func toggleGroup(_ group: StudyPlanGroup) {
        if isGroupFullySelected(group) {
            for course in group.courses { selectedCourseCodes.remove(course.code) }
        } else {
            for course in group.courses { selectedCourseCodes.insert(course.code) }
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

/// Semester-seksjonsoverskrift med en "velg alle / fjern alle"-knapp, slik at man kan
/// huke av et helt semester i ett trykk i stedet for hvert emne enkeltvis — og likevel
/// justere enkeltemner etterpå via radene under.
private struct SemesterSectionHeader: View {
    let title: String
    let allSelected: Bool
    let toggle: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(allSelected ? "Fjern alle" : "Velg alle", action: toggle)
                .font(.caption)
                .buttonStyle(.borderless)
                .textCase(nil)
        }
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
