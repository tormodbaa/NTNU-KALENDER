import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var viewModel: ScheduleViewModel

    @State private var mode: Mode = .week
    @State private var anchorDate: Date = .init()
    @State private var selectedEvent: ScheduleEvent?
    @State private var showingExportSheet = false
    @State private var icsURL: URL?
    @State private var exportAlert: ExportAlert?

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
                    }

                    Group {
                        switch mode {
                        case .week:
                            WeekGridView(
                                weekDays: weekDays,
                                eventsByDay: eventsByDay,
                                colorFor: colorFor,
                                hasConflict: viewModel.hasConflict,
                                onTap: { selectedEvent = $0 }
                            )
                        case .day:
                            DayPagerView(
                                days: weekDays,
                                anchorDate: $anchorDate,
                                eventsByDay: eventsByDay,
                                colorFor: colorFor,
                                hasConflict: viewModel.hasConflict,
                                onTap: { selectedEvent = $0 }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Timeplan")
            .toolbar {
                if !viewModel.selectedCourses.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Del som .ics", systemImage: "square.and.arrow.up") { exportICS() }
                            Button("Legg i Apple Kalender", systemImage: "calendar.badge.plus") {
                                Task { await exportToCalendar() }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Ingen emner valgt", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("Legg til emner under \"Emner\"-fanen for å generere timeplanen din.")
        }
    }

    private var weekNavigationHeader: some View {
        HStack {
            Button { anchorDate = anchorDate.addingDays(-7) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text("Uke \(anchorDate.weekOfYear) · \(weekDays.first?.formatted("d.M") ?? "") – \(weekDays.last?.formatted("d.M") ?? "")")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { anchorDate = anchorDate.addingDays(7) } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.top, 6)
    }

    private var weekDays: [Date] {
        let monday = anchorDate.mondayOfWeek()
        return (0..<5).map { monday.addingDays($0) }
    }

    private var eventsByDay: [Date: [ScheduleEvent]] {
        Dictionary(grouping: viewModel.events) { $0.start.startOfDay() }
    }

    private func colorFor(_ courseCode: String) -> Color {
        viewModel.selectedCourses.first { $0.code == courseCode }?.color.color ?? .gray
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
