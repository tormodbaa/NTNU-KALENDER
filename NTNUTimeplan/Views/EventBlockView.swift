import SwiftUI

/// En enkelt timeplanhendelse tegnet som en farget boks. Brukes både i ukevisningens
/// smale dagskolonner og i den bredere dagvisningen (styrt av `style`).
struct EventBlockView: View {
    enum Style { case compact, detailed }

    let event: ScheduleEvent
    let color: Color
    let hasConflict: Bool
    let style: Style

    private var mazeMapURL: URL? { event.rooms.first?.mazeMapURL }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .detailed ? 2 : 0) {
            Text(event.courseCode)
                .font(style == .detailed ? .caption.weight(.bold) : .caption2.weight(.bold))
                .lineLimit(1)
            Text(event.title)
                .font(style == .detailed ? .caption : .system(size: 9))
                .lineLimit(style == .detailed ? 2 : 1)
            if style == .detailed, let room = event.rooms.first {
                Label(room.displayName, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, style == .detailed ? 8 : 4)
        .padding(.vertical, style == .detailed ? 6 : 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.gradient)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if hasConflict {
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(.orange, lineWidth: 1.5))
                    .padding(4)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if style == .detailed, let mazeMapURL {
                Link(destination: mazeMapURL) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.white.opacity(0.25), in: Circle())
                }
                .padding(4)
            }
        }
    }
}

/// Rolig, lavmælt visning for lange "åpne" økter (se `ScheduleEvent.isExtendedSession`),
/// f.eks. et 10-timers lab-vindu — vises som et tynt, gjennomsiktig bånd i bakgrunnen i
/// stedet for en solid boks, slik at det ikke ser ut som en obligatorisk sammenhengende time.
struct ExtendedSessionBand: View {
    let event: ScheduleEvent
    let color: Color
    let style: EventBlockView.Style

    var body: some View {
        HStack(spacing: 4) {
            Text(event.courseCode)
                .font(style == .detailed ? .caption2.weight(.semibold) : .system(size: 8, weight: .semibold))
            if style == .detailed {
                Text(event.title)
                    .font(.caption2)
                Spacer()
                Text("\(event.start.formatted("HH:mm"))–\(event.end.formatted("HH:mm"))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(color.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        )
    }
}
