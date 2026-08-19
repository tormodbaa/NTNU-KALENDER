import SwiftUI

/// En enkelt timeplanhendelse tegnet som en farget boks. Brukes både i ukevisningens
/// smale dagskolonner og i den bredere dagvisningen (styrt av `style`).
struct EventBlockView: View {
    enum Style { case compact, detailed }

    let event: ScheduleEvent
    let color: Color
    let hasConflict: Bool
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: style == .detailed ? 2 : 0) {
            Text(event.courseCode)
                .font(style == .detailed ? .caption.bold() : .caption2.bold())
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(hasConflict ? Color.red : .clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if hasConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(Circle().fill(Color.red))
                    .padding(3)
            }
        }
    }
}
