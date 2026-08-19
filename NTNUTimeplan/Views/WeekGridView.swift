import SwiftUI

struct WeekGridView: View {
    let weekDays: [Date]
    let eventsByDay: [Date: [ScheduleEvent]]
    let colorFor: (String) -> Color
    let hasConflict: (ScheduleEvent) -> Bool
    let onTap: (ScheduleEvent) -> Void

    private let hourHeight: CGFloat = 52

    var body: some View {
        let allEvents = weekDays.flatMap { eventsByDay[$0] ?? [] }
        let metrics = TimelineMetrics(events: allEvents, hourHeight: hourHeight)

        ScrollView {
            HStack(alignment: .top, spacing: 4) {
                TimeAxisView(metrics: metrics)
                    .frame(width: 32)
                    .padding(.top, 28)

                ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: 4) {
                        DayHeader(day: day)

                        let dayEvents = eventsByDay[day] ?? []
                        let laidOut = DayLayout.layout(dayEvents)

                        GeometryReader { proxy in
                            ZStack(alignment: .topLeading) {
                                HourGridLines(metrics: metrics)

                                ForEach(laidOut) { item in
                                    let width = proxy.size.width / CGFloat(item.columnCount)
                                    EventBlockView(
                                        event: item.event,
                                        color: colorFor(item.event.courseCode),
                                        hasConflict: hasConflict(item.event),
                                        style: .compact
                                    )
                                    .frame(width: width - 2, height: metrics.height(from: item.event.start, to: item.event.end))
                                    .offset(
                                        x: CGFloat(item.column) * width + 1,
                                        y: metrics.yOffset(for: item.event.start)
                                    )
                                    .onTapGesture { onTap(item.event) }
                                }
                            }
                        }
                        .frame(height: metrics.totalHeight)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

private struct DayHeader: View {
    let day: Date

    private var isToday: Bool { Calendar.ntnu.isDateInToday(day) }

    var body: some View {
        VStack(spacing: 1) {
            Text(day.formatted("EEE"))
                .font(.caption2.bold())
                .foregroundStyle(isToday ? Color.accentColor : .secondary)
            Text(day.formatted("d.M"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(height: 24)
    }
}
