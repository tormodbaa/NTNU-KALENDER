import CoreGraphics
import Foundation

/// Regner om klokkeslett til vertikale piksel-posisjoner for kalendervisningene.
struct TimelineMetrics {
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat

    init(events: [ScheduleEvent], hourHeight: CGFloat) {
        // Lange "åpne" økter (se `ScheduleEvent.isExtendedSession`) skal ikke få
        // tidsaksen til å strekke seg over hele dagen — bruk vanlige forelesninger
        // til å bestemme det synlige tidsvinduet, med de lange øktene som fallback
        // hvis det ikke finnes andre hendelser å vise.
        let regular = events.filter { !$0.isExtendedSession }
        let relevant = regular.isEmpty ? events : regular
        let starts = relevant.map { $0.start.hourFraction }
        let ends = relevant.map { $0.end.hourFraction }
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

    /// Som `height(from:to:)`, men klippet slik at den aldri stikker under synlig
    /// tidsvindu — brukes for lange økter som kan starte før/slutte etter aksens grenser.
    func clampedHeight(from start: Date, to end: Date) -> CGFloat {
        let top = yOffset(for: start)
        let naturalBottom = top + height(from: start, to: end)
        let clampedBottom = min(naturalBottom, totalHeight)
        return max(20, clampedBottom - max(0, top))
    }
}
