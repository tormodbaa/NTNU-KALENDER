import CoreGraphics
import Foundation

/// Regner om klokkeslett til vertikale piksel-posisjoner for kalendervisningene.
struct TimelineMetrics {
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat

    init(events: [ScheduleEvent], hourHeight: CGFloat) {
        let starts = events.map { $0.start.hourFraction }
        let ends = events.map { $0.end.hourFraction }
        self.startHour = max(0, Int((starts.min() ?? 8).rounded(.down)) - 1)
        self.endHour = min(24, Int((ends.max() ?? 18).rounded(.up)) + 1)
        self.hourHeight = hourHeight
    }

    var hours: [Int] { Array(startHour...max(startHour, endHour)) }

    var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    func yOffset(for date: Date) -> CGFloat {
        CGFloat(date.hourFraction - Double(startHour)) * hourHeight
    }

    func height(from start: Date, to end: Date) -> CGFloat {
        max(20, CGFloat(end.hourFraction - start.hourFraction) * hourHeight)
    }
}
