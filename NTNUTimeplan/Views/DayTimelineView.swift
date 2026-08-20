import SwiftUI

struct DayTimelineView: View {
    let day: Date
    let events: [ScheduleEvent]
    let colorFor: (String) -> Color
    let hasConflict: (ScheduleEvent) -> Bool
    let onTap: (ScheduleEvent) -> Void

    private let hourHeight: CGFloat = 72

    var body: some View {
        let metrics = TimelineMetrics(events: events, hourHeight: hourHeight)
        let extendedEvents = events.filter(\.isExtendedSession)
        let laidOut = DayLayout.layout(events.filter { !$0.isExtendedSession })

        ScrollView {
            HStack(alignment: .top, spacing: 8) {
                TimeAxisView(metrics: metrics)
                    .frame(width: 44)

                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        HourGridLines(metrics: metrics)

                        ForEach(extendedEvents) { event in
                            ExtendedSessionBand(event: event, color: colorFor(event.courseCode), style: .detailed)
                                .frame(height: metrics.clampedHeight(from: event.start, to: event.end))
                                .offset(y: metrics.yOffset(for: event.start))
                                .onTapGesture { onTap(event) }
                        }

                        ForEach(laidOut) { item in
                            let width = proxy.size.width / CGFloat(item.columnCount)
                            EventBlockView(
                                event: item.event,
                                color: colorFor(item.event.courseCode),
                                hasConflict: hasConflict(item.event),
                                style: .detailed
                            )
                            .frame(width: width - 4, height: metrics.height(from: item.event.start, to: item.event.end))
                            .offset(
                                x: CGFloat(item.column) * width + 2,
                                y: metrics.yOffset(for: item.event.start)
                            )
                            .onTapGesture { onTap(item.event) }
                        }

                        if Calendar.ntnu.isDateInToday(day) {
                            CurrentTimeIndicator(metrics: metrics)
                        }
                    }
                }
                .frame(height: metrics.totalHeight)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct TimeAxisView: View {
    let metrics: TimelineMetrics

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(metrics.hours, id: \.self) { hour in
                Text("\(hour):00")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .offset(y: metrics.yOffset(for: hourDate(hour)) - 6)
            }
        }
        .frame(height: metrics.totalHeight, alignment: .topLeading)
    }

    private func hourDate(_ hour: Int) -> Date {
        Calendar.ntnu.date(bySettingHour: hour, minute: 0, second: 0, of: .init()) ?? .init()
    }
}

struct HourGridLines: View {
    let metrics: TimelineMetrics

    var body: some View {
        VStack(spacing: 0) {
            ForEach(metrics.hours, id: \.self) { _ in
                Divider()
                Spacer(minLength: metrics.hourHeight - 1)
            }
        }
        .frame(height: metrics.totalHeight)
    }
}
