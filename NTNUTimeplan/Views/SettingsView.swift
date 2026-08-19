import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingClearConfirmation = false

    private static let leadOptions = [5, 10, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Varsle før forelesning", isOn: notificationsBinding)
                    if viewModel.notificationsEnabled {
                        Picker("Varsle før", selection: leadMinutesBinding) {
                            ForEach(Self.leadOptions, id: \.self) { minutes in
                                Text("\(minutes) minutter").tag(minutes)
                            }
                        }
                    }
                } header: {
                    Text("Varslinger")
                } footer: {
                    Text("Du får et push-varsel på telefonen et gitt antall minutter før hver time i valgte emner.")
                }

                Section {
                    Button("Fjern alle emner i \"\(viewModel.activeTimeplan.name)\"", role: .destructive) {
                        showingClearConfirmation = true
                    }
                    .disabled(viewModel.selectedCourses.isEmpty)
                } header: {
                    Text("Data")
                }
            }
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ferdig") { dismiss() }
                }
            }
            .confirmationDialog(
                "Fjerne alle emner i \"\(viewModel.activeTimeplan.name)\"?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Fjern alle", role: .destructive) { viewModel.removeAllCourses() }
                Button("Avbryt", role: .cancel) {}
            }
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationsEnabled },
            set: { newValue in Task { await viewModel.setNotificationsEnabled(newValue) } }
        )
    }

    private var leadMinutesBinding: Binding<Int> {
        Binding(
            get: { viewModel.notificationLeadMinutes },
            set: { newValue in Task { await viewModel.updateNotificationLeadMinutes(newValue) } }
        )
    }
}
