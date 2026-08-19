import Foundation

/// Enkel intervall-layout: overlappende hendelser får hver sin kolonne side ved side
/// i stedet for å tegnes oppå hverandre, slik at kollisjoner er synlige og lesbare.
struct LaidOutEvent: Identifiable {
    let event: ScheduleEvent
    let column: Int
    let columnCount: Int
    var id: String { event.id }
}

enum DayLayout {
    static func layout(_ events: [ScheduleEvent]) -> [LaidOutEvent] {
        let sorted = events.sorted { $0.start < $1.start }
        var columnEndTimes: [Date] = []
        var assigned: [(event: ScheduleEvent, column: Int)] = []

        for event in sorted {
            if let freeIndex = columnEndTimes.firstIndex(where: { $0 <= event.start }) {
                columnEndTimes[freeIndex] = event.end
                assigned.append((event, freeIndex))
            } else {
                columnEndTimes.append(event.end)
                assigned.append((event, columnEndTimes.count - 1))
            }
        }

        return assigned.map { entry in
            let overlappingCount = assigned
                .filter { $0.event.start < entry.event.end && $0.event.end > entry.event.start }
                .map(\.column)
                .max().map { $0 + 1 } ?? 1
            return LaidOutEvent(event: entry.event, column: entry.column, columnCount: max(overlappingCount, entry.column + 1))
        }
    }
}
