import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    @EnvironmentObject var subscriptions: SubscriptionManager

    @State private var mode: Mode = .week
    @State private var anchorDate: Date = .init()
    @State private var selectedEvent: ScheduleEvent?
    @State private var showingExportSheet = false
    @State private var icsURL: URL?
    @State private var exportAlert: ExportAlert?
    @State private var showingTimeplanManager = false
    @State private var showingSettings = false

    enum Mode: String, CaseIterable { case week = "Uke", day = "Dag" }

    private struct ExportAlert: Identifiable {
        enum Kind { case success, failure(String) }
        let kind: Kind
        var id: String { "alert" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.selectedCourses.isEmpty {
                    emptyState
                } else {
                    Picker("Visning", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding([.horizontal, .top])

                    weekNavigationHeader

                    if viewModel.usingDemoData {
                        DemoDataBanner()
                    } else if viewModel.myStudyProgram == nil && !viewModel.conflictingEventIDs.isEmpty {
                        MissingProgramBanner { showingSettings = true }
                    }

                    calendarContent
                }
            }
            .navigationTitle(viewModel.activeTimeplan.name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingTimeplanManager = true
                    } label: {
                        Label("Kalendere", systemImage: "calendar.badge.clock")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !viewModel.selectedCourses.isEmpty {
                        Menu {
                            Button("Del som .ics", systemImage: "square.and.arrow.up") { exportICS() }
                            Button("Legg i Apple Kalender", systemImage: "calendar.badge.plus") {
                                Task { await exportToCalendar() }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event, courseName: courseName(for: event.courseCode))
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingExportSheet) {
                if let icsURL {
                    ShareSheet(items: [icsURL])
                }
            }
            .sheet(isPresented: $showingTimeplanManager) {
                TimeplanManagerView().environmentObject(viewModel)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(viewModel)
                    .environmentObject(subscriptions)
            }
            .alert(item: $exportAlert) { alert in
                switch alert.kind {
                case .success:
                    Alert(title: Text("Lagt til i Kalender"), message: Text("Timeplanen ble lagt inn i kalenderen \"NTNU Timeplan\"."))
                case .failure(let message):
                    Alert(title: Text("Kunne ikke eksportere"), message: Text(message))
                }
            }
        }
    }

    /// Skilt ut i egen `View` slik at fargetabellen og dagene bare regnes ut én gang
    /// per tegning og deles av alle undervisningene, i stedet for ett oppslag per boks.
    private var calendarContent: some View {
        let colors = viewModel.courseColors
        let days = weekDays
        let conflicts = viewModel.conflictingEventIDs
        return Group {
            switch mode {
            case .week:
                WeekGridView(
                    weekDays: days,
                    eventsByDay: viewModel.eventsByDay,
                    colorFor: { colors[$0] ?? .gray },
                    hasConflict: { conflicts.contains($0.id) },
                    onTap: { selectedEvent = $0 }
                )
            case .day:
                DayPagerView(
                    days: days,
                    anchorDate: $anchorDate,
                    eventsByDay: viewModel.eventsByDay,
                    colorFor: { colors[$0] ?? .gray },
                    hasConflict: { conflicts.contains($0.id) },
                    onTap: { selectedEvent = $0 }
                )
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Ingen emner valgt", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Legg til emner under \"Emner\"-fanen for å generere timeplanen din.")
        }
    }

    private var weekNavigationHeader: some View {
        HStack {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            VStack(spacing: 1) {
                Text("Uke \(anchorDate.weekOfYear) · \(weekDays.first?.formatted("d.M") ?? "") – \(weekDays.last?.formatted("d.M") ?? "")")
                    .font(.subheadline.weight(.semibold))
                if !Calendar.ntnu.isDateInToday(anchorDate) {
                    Button("Gå til i dag") { anchorDate = Date() }
                        .font(.caption2)
                }
            }
            Spacer()
            Button { step(1) } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    /// I ukevisning hopper pilene en hel uke; i dagvisning skal de bla én dag om
    /// gangen (og hoppe over helg, siden timeplanen bare dekker man.–fre.).
    private func step(_ direction: Int) {
        switch mode {
        case .week:
            anchorDate = anchorDate.addingDays(7 * direction)
        case .day:
            var next = anchorDate.addingDays(direction)
            while next.isoWeekday > 5 {
                next = next.addingDays(direction)
            }
            anchorDate = next
        }
    }

    private var weekDays: [Date] {
        let monday = anchorDate.mondayOfWeek()
        return (0..<5).map { monday.addingDays($0) }
    }

    private func courseName(for code: String) -> String {
        viewModel.selectedCourses.first { $0.code == code }?.name ?? code
    }

    private func exportICS() {
        do {
            icsURL = try ICSExporter.writeTemporaryFile(events: viewModel.events, courses: viewModel.selectedCourses)
            showingExportSheet = true
        } catch {
            exportAlert = ExportAlert(kind: .failure("Klarte ikke å lage .ics-filen."))
        }
    }

    private func exportToCalendar() async {
        let exporter = EventKitExporter()
        do {
            try await exporter.requestAccess()
            try exporter.replaceEvents(with: viewModel.events, courses: viewModel.selectedCourses)
            exportAlert = ExportAlert(kind: .success)
        } catch {
            exportAlert = ExportAlert(kind: .failure(error.localizedDescription))
        }
    }
}

private struct DemoDataBanner: View {
    var body: some View {
        Label("Viser demo-data — NTNUs API svarte ikke", systemImage: "wifi.exclamationmark")
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(.horizontal)
            .padding(.top, 4)
    }
}

private struct MissingProgramBanner: View {
    let onFix: () -> Void

    var body: some View {
        Button(action: onFix) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                Text("Ser doble timer? Angi studieprogrammet ditt for å vise riktig gruppe")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 6)
    }
}
