import SwiftUI

struct EventDetailSheet: View {
    let event: ScheduleEvent
    let courseName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Emne", value: "\(event.courseCode) – \(courseName)")
                    LabeledContent("Type") {
                        Label(event.kind.shortLabel, systemImage: event.kind.symbolName)
                    }
                    LabeledContent("Tidspunkt", value: timeRangeText)
                    LabeledContent("Uke", value: "\(event.week)")
                }

                if !event.rooms.isEmpty {
                    Section("Rom") {
                        ForEach(event.rooms, id: \.self) { room in
                            if let url = room.mazeMapURL {
                                Link(destination: url) {
                                    Label(room.displayName, systemImage: "map")
                                }
                            } else {
                                Label(room.displayName, systemImage: "mappin.and.ellipse")
                            }
                        }
                    }
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ferdig") { dismiss() }
                }
            }
        }
    }

    private var timeRangeText: String {
        "\(event.start.formatted("EEEE d. MMM, HH:mm")) – \(event.end.formatted("HH:mm"))"
    }
}
