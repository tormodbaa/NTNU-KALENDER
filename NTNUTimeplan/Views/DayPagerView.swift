import SwiftUI

struct DayPagerView: View {
    let days: [Date]
    @Binding var anchorDate: Date
    let eventsByDay: [Date: [ScheduleEvent]]
    let colorFor: (String) -> Color
    let hasConflict: (ScheduleEvent) -> Bool
    let onTap: (ScheduleEvent) -> Void

    @State private var selectedDay: Date = .init()

    var body: some View {
        TabView(selection: $selectedDay) {
            ForEach(days, id: \.self) { day in
                DayPage(
                    day: day,
                    events: eventsByDay[day] ?? [],
                    colorFor: colorFor,
                    hasConflict: hasConflict,
                    onTap: onTap
                )
                .tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            selectedDay = days.first { Calendar.ntnu.isDate($0, inSameDayAs: anchorDate) } ?? (days.first ?? anchorDate)
        }
        .onChange(of: anchorDate) { _, newValue in
            if let match = days.first(where: { Calendar.ntnu.isDate($0, inSameDayAs: newValue) }),
               !Calendar.ntnu.isDate(selectedDay, inSameDayAs: match) {
                selectedDay = match
            }
        }
        .onChange(of: selectedDay) { _, newValue in
            // Hold `anchorDate` i sync når brukeren sveiper med fingeren (ikke bare
            // når pilene i headeren trykkes), slik at "Gå til i dag" og ukenummeret
            // over alltid stemmer med siden som faktisk vises.
            if !Calendar.ntnu.isDate(anchorDate, inSameDayAs: newValue) {
                anchorDate = newValue
            }
        }
    }
}

/// Én side i dagvisningen. Egen `View` (ikke inline i `ForEach`) slik at SwiftUI kan
/// diffe og hoppe over sider hvis dataene deres ikke har endret seg, i stedet for å
/// bygge alle fem dagene på nytt hver gang `anchorDate` oppdateres under en sveip.
private struct DayPage: View {
    let day: Date
    /// Forventes allerede sortert etter starttid (se `ScheduleViewModel.eventsByDay`).
    let events: [ScheduleEvent]
    let colorFor: (String) -> Color
    let hasConflict: (ScheduleEvent) -> Bool
    let onTap: (ScheduleEvent) -> Void

    var body: some View {
        VStack(spacing: 2) {
            Text(day.formatted("EEEE d. MMMM"))
                .font(.subheadline.weight(.semibold))
                .padding(.top, 4)

            if events.isEmpty {
                Spacer()
                Text("Ingen undervisning denne dagen")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                DayTimelineView(
                    day: day,
                    events: events,
                    colorFor: colorFor,
                    hasConflict: hasConflict,
                    onTap: onTap
                )
            }
        }
    }
}
