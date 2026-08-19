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
                    Section {
                        ForEach(event.rooms, id: \.self) { room in
                            if let url = room.mazeMapURL {
                                Link(destination: url) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(room.name).font(.body)
                                            if let building = room.building {
                                                Text(building).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Label("Åpne kart", systemImage: "map.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.accentColor, in: Capsule())
                                    }
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(room.name).font(.body)
                                    if let building = room.building {
                                        Text(building).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Rom")
                    } footer: {
                        if event.rooms.contains(where: { $0.mazeMapURL != nil }) {
                            Text("Åpner bygningens plassering på MazeMap.")
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
