import SwiftUI

struct CourseSearchView: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    @State private var showingStudyProgramImport = false

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.selectedCourses.isEmpty {
                    Section {
                        ForEach(viewModel.selectedCourses) { course in
                            HStack {
                                Circle().fill(course.color.color).frame(width: 12, height: 12)
                                VStack(alignment: .leading) {
                                    Text(course.code).font(.subheadline.weight(.semibold))
                                    Text(course.name).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.removeCourse(viewModel.selectedCourses[index].code)
                            }
                        }
                    } header: {
                        Text("Mine emner")
                    } footer: {
                        Text("Sveip til venstre for å fjerne et emne.")
                    }
                }

                Section {
                    Button {
                        showingStudyProgramImport = true
                    } label: {
                        Label("Legg til hele studieretningen din", systemImage: "graduationcap")
                    }
                }

                Section {
                    if viewModel.isLoadingCatalog {
                        HStack {
                            ProgressView()
                            Text("Henter emnekatalog fra NTNU …").foregroundStyle(.secondary)
                        }
                    } else if !viewModel.searchQuery.isEmpty && viewModel.searchResults.isEmpty {
                        Text("Ingen emner funnet for \"\(viewModel.searchQuery)\".")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.searchResults) { (listing: CourseListing) in
                        SearchResultRow(listing: listing)
                    }
                } header: {
                    Text("Søk")
                } footer: {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage).foregroundStyle(.orange)
                    }
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Emnekode eller emnenavn")
            .navigationTitle("Emner")
            .task { await viewModel.loadCatalogIfNeeded() }
            .sheet(isPresented: $showingStudyProgramImport) {
                StudyProgramImportView().environmentObject(viewModel)
            }
        }
    }
}

private struct SearchResultRow: View {
    @EnvironmentObject var viewModel: ScheduleViewModel
    let listing: CourseListing

    var body: some View {
        let selected = viewModel.isSelected(listing.code)
        Button {
            viewModel.addCourse(listing)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(listing.code).font(.subheadline.weight(.semibold))
                    Text(listing.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(selected ? Color.green : Color.accentColor)
            }
        }
        .disabled(selected)
        .buttonStyle(.plain)
    }
}
