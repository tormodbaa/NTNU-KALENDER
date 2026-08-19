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
                VStack(spacing: 2) {
                    Text(day.formatted("EEEE d. MMMM"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)

                    let dayEvents = (eventsByDay[day] ?? []).sorted { $0.start < $1.start }
                    if dayEvents.isEmpty {
                        Spacer()
                        Text("Ingen undervisning denne dagen")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        DayTimelineView(
                            day: day,
                            events: dayEvents,
                            colorFor: colorFor,
                            hasConflict: hasConflict,
                            onTap: onTap
                        )
                    }
                }
                .tag(day)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .onAppear {
            selectedDay = days.first { Calendar.ntnu.isDate($0, inSameDayAs: anchorDate) } ?? (days.first ?? anchorDate)
        }
        .onChange(of: anchorDate) { _, newValue in
            if let match = days.first(where: { Calendar.ntnu.isDate($0, inSameDayAs: newValue) }) {
                selectedDay = match
            }
        }
    }
}
