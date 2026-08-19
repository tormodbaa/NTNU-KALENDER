import SwiftUI

/// Lar brukeren skrive inn en studieprogramkode (f.eks. "MTDT"), velge kull/opptaksår,
/// og krysse av hvilke emner fra studieplanen som skal legges til i aktiv kalender.
struct StudyProgramImportView: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var programCode = ""
    @State private var years: [Int] = []
    @State private var selectedYear: Int?
    @State private var plan: StudyPlan?
    @State private var selectedCourseCodes: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Programkode, f.eks. MTDT", text: $programCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await loadYears() } }
                    Button("Finn studieprogram") { Task { await loadYears() } }
                        .disabled(programCode.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                } header: {
                    Text("Studieprogram")
                } footer: {
                    Text("Skriv inn NTNUs kode for studieprogrammet ditt, f.eks. MTDT (Datateknologi) eller BIDATA (Dataingeniør).")
                }

                if !years.isEmpty {
                    Section("Kull (opptaksår)") {
                        Picker("Opptaksår", selection: yearBinding) {
                            ForEach(years, id: \.self) { year in
                                Text("\(year)").tag(year)
                            }
                        }
                        .pickerStyle(.menu)
                    }
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
            .navigationTitle("Legg til studieretning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
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
        }
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
        plan = nil
        years = []
        defer { isLoading = false }
        do {
            let code = programCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            programCode = code
            years = try await viewModel.fetchStudyPlanYears(programCode: code)
            selectedYear = years.first
            await loadPlan()
        } catch {
            errorMessage = "Fant ikke studieprogrammet \"\(programCode)\". Sjekk at koden er riktig."
        }
    }

    private func loadPlan() async {
        guard let year = selectedYear else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await viewModel.fetchStudyPlan(programCode: programCode, year: year)
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
