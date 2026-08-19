import SwiftUI

/// Lar brukeren bytte mellom flere navngitte kalendere (Timeplaner), opprette nye,
/// gi dem nytt navn, og slette dem (minst én kalender må alltid finnes).
struct TimeplanManagerView: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingNewPlanAlert = false
    @State private var newPlanName = ""
    @State private var renamingPlan: Timeplan?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.timeplaner) { plan in
                    TimeplanRow(
                        plan: plan,
                        isActive: plan.id == viewModel.activeTimeplanID,
                        canDelete: viewModel.timeplaner.count > 1,
                        onSelect: {
                            viewModel.selectTimeplan(plan.id)
                            dismiss()
                        },
                        onDelete: { viewModel.deleteTimeplan(plan.id) },
                        onRename: {
                            renamingPlan = plan
                            renameText = plan.name
                        }
                    )
                }
            }
            .navigationTitle("Kalendere")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ferdig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newPlanName = ""
                        showingNewPlanAlert = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Ny kalender", isPresented: $showingNewPlanAlert) {
                TextField("Navn", text: $newPlanName)
                Button("Avbryt", role: .cancel) {}
                Button("Opprett") { viewModel.createTimeplan(name: newPlanName) }
            }
            .alert("Endre navn", isPresented: Binding(
                get: { renamingPlan != nil },
                set: { if !$0 { renamingPlan = nil } }
            )) {
                TextField("Navn", text: $renameText)
                Button("Avbryt", role: .cancel) {}
                Button("Lagre") {
                    if let plan = renamingPlan {
                        viewModel.renameTimeplan(plan.id, to: renameText)
                    }
                }
            }
        }
    }
}

private struct TimeplanRow: View {
    let plan: Timeplan
    let isActive: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name).font(.body)
                    Text("\(plan.courses.count) emner").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if canDelete {
                Button("Slett", systemImage: "trash", role: .destructive, action: onDelete)
            }
            Button("Endre navn", systemImage: "pencil", action: onRename)
                .tint(.orange)
        }
    }
}
