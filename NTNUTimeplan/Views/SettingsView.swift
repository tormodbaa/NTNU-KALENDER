import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingClearConfirmation = false
    @State private var showingProgramPicker = false
    @State private var calendarName = ""

    /// I minutter. Vist med naturlige norske etiketter i `leadLabel(_:)`.
    private static let leadOptions = [5, 10, 15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                Section("Kalender") {
                    TextField("Navn på kalenderen", text: $calendarName)
                        .onSubmit(renameActiveTimeplan)
                        .onChange(of: calendarName) { _, _ in renameActiveTimeplan() }
                }

                Section {
                    Button {
                        showingProgramPicker = true
                    } label: {
                        HStack {
                            Text("Mitt studieprogram")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(viewModel.myStudyProgram?.code ?? "Ikke valgt")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if viewModel.myStudyProgram != nil {
                        Button("Fjern studieprogram", role: .destructive) {
                            Task { await viewModel.setMyStudyProgram(nil) }
                        }
                    }
                } header: {
                    Text("Studieprogram")
                } footer: {
                    Text("Mange fellesemner har flere parallelle grupper (ulikt rom/tidspunkt) registrert per studieprogram. Uten dette valgt vises alle grupper, som kan se ut som overlappende timer selv om de egentlig ikke gjelder deg.")
                }

                Section {
                    Toggle("Varsle før timer", isOn: notificationsBinding)
                    if viewModel.notificationPermissionDenied {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Åpne Innstillinger", systemImage: "gearshape")
                        }
                    }
                    if viewModel.notificationsEnabled {
                        Picker("Varsle før", selection: leadMinutesBinding) {
                            ForEach(Self.leadOptions, id: \.self) { minutes in
                                Text(Self.leadLabel(minutes)).tag(minutes)
                            }
                        }
                    }
                } header: {
                    Text("Varslinger")
                } footer: {
                    if viewModel.notificationPermissionDenied {
                        Text("Varsler er blokkert for appen i iOS. Skru dem på under Varsler i Innstillinger, kom så tilbake hit.")
                    } else {
                        Text("Du får et push-varsel på telefonen et gitt antall tid før hver time i valgte emner.")
                    }
                }

                if viewModel.notificationsEnabled {
                    Section {
                        // Kun typene `classify()` faktisk kan produsere — `.exercise`
                        // finnes i modellen, men slås alltid sammen med `.lab` ("Lab/øving")
                        // og ville derfor vært en bryter som aldri gjorde noe.
                        ForEach([EventKind.lecture, .lab, .seminar, .exam, .other], id: \.self) { kind in
                            Toggle(kind.shortLabel, isOn: kindBinding(kind))
                        }
                    } header: {
                        Text("Varsle for disse timetypene")
                    } footer: {
                        Text("Skru av f.eks. \"Lab/øving\" hvis du bare vil ha varsel før forelesninger.")
                    }

                    if !viewModel.selectedCourses.isEmpty {
                        Section("Varsle for disse emnene") {
                            ForEach(viewModel.selectedCourses) { course in
                                Toggle(isOn: courseBinding(course.code)) {
                                    HStack {
                                        Circle().fill(course.color.color).frame(width: 10, height: 10)
                                        Text("\(course.code) – \(course.name)")
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Fjern alle emner i \"\(viewModel.activeTimeplan.name)\"", role: .destructive) {
                        showingClearConfirmation = true
                    }
                    .disabled(viewModel.selectedCourses.isEmpty)
                } header: {
                    Text("Data")
                }
            }
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ferdig") { dismiss() }
                }
            }
            .onAppear { calendarName = viewModel.activeTimeplan.name }
            .task { await viewModel.refreshNotificationPermissionStatus() }
            .confirmationDialog(
                "Fjerne alle emner i \"\(viewModel.activeTimeplan.name)\"?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Fjern alle", role: .destructive) { viewModel.removeAllCourses() }
                Button("Avbryt", role: .cancel) {}
            }
            .sheet(isPresented: $showingProgramPicker) {
                NavigationStack {
                    StudyProgramSearchList { program in
                        Task { await viewModel.setMyStudyProgram(program) }
                        showingProgramPicker = false
                    }
                    .navigationTitle("Mitt studieprogram")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Avbryt") { showingProgramPicker = false }
                        }
                    }
                }
                .environmentObject(viewModel)
            }
        }
    }

    private func renameActiveTimeplan() {
        let trimmed = calendarName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.renameTimeplan(viewModel.activeTimeplanID, to: trimmed)
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationsEnabled },
            set: { newValue in Task { await viewModel.setNotificationsEnabled(newValue) } }
        )
    }

    private var leadMinutesBinding: Binding<Int> {
        Binding(
            get: { viewModel.notificationLeadMinutes },
            set: { newValue in Task { await viewModel.updateNotificationLeadMinutes(newValue) } }
        )
    }

    private func courseBinding(_ code: String) -> Binding<Bool> {
        Binding(
            get: { !viewModel.mutedCourseCodes.contains(code) },
            set: { newValue in Task { await viewModel.setCourseMuted(code, muted: !newValue) } }
        )
    }

    private func kindBinding(_ kind: EventKind) -> Binding<Bool> {
        Binding(
            get: { !viewModel.mutedEventKinds.contains(kind) },
            set: { newValue in Task { await viewModel.setKindMuted(kind, muted: !newValue) } }
        )
    }

    private static func leadLabel(_ minutes: Int) -> String {
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 time før" : "\(hours) timer før"
        }
        if minutes == 90 {
            return "1,5 time før"
        }
        return "\(minutes) minutter før"
    }
}
