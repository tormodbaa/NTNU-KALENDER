import SwiftUI

/// Søk opp et studieprogram blant NTNUs ~400 programmer. Gjenbrukt både av
/// `StudyProgramImportView` (bulk-import av emner) og `SettingsView` (velge "mitt
/// studieprogram" for å filtrere bort parallellgrupper som ikke gjelder deg).
struct StudyProgramSearchList: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    let onSelect: (StudyProgramListing) -> Void

    @State private var query = ""
    @State private var catalog: [StudyProgramListing] = []
    @State private var isLoadingCatalog = false
    @State private var errorMessage: String?

    private var results: [StudyProgramListing] {
        viewModel.searchPrograms(query, in: catalog)
    }

    var body: some View {
        List {
            Section {
                if isLoadingCatalog {
                    HStack {
                        ProgressView()
                        Text("Henter studieprogrammer fra NTNU …").foregroundStyle(.secondary)
                    }
                } else if !query.isEmpty && results.isEmpty {
                    Text("Ingen studieprogram funnet for \"\(query)\".").foregroundStyle(.secondary)
                }

                ForEach(results) { program in
                    Button {
                        onSelect(program)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(program.name).font(.subheadline.weight(.semibold))
                            Text("\(program.code) · \(program.studyLevel)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.orange)
                }
            }
        }
        .searchable(text: $query, prompt: "Studieprogram, f.eks. Datateknologi eller MTDT")
        .task { await loadCatalog() }
    }

    private func loadCatalog() async {
        guard catalog.isEmpty else { return }
        isLoadingCatalog = true
        defer { isLoadingCatalog = false }
        do {
            catalog = try await viewModel.loadProgramCatalog()
        } catch {
            errorMessage = "Fant ikke listen over studieprogrammer akkurat nå. Prøv igjen om litt."
        }
    }
}
