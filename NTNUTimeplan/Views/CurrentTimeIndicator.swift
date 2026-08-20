import SwiftUI

/// En rød linje som viser klokkeslettet akkurat nå på tidslinjen, à la Apple Kalender.
/// Oppdaterer seg selv hvert minutt via `TimelineView` — ingen egen Timer/Combine nødvendig.
struct CurrentTimeIndicator: View {
    let metrics: TimelineMetrics

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let offset = metrics.yOffset(for: context.date)
            if offset >= 0, offset <= metrics.totalHeight {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 1.5)
                }
                .offset(y: offset - 4)
                .allowsHitTesting(false)
            }
        }
    }
}
