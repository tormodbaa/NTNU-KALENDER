import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScheduleViewModel()

    var body: some View {
        TabView {
            ScheduleView()
                .tabItem { Label("Timeplan", systemImage: "calendar") }

            CourseSearchView()
                .tabItem { Label("Emner", systemImage: "magnifyingglass") }
        }
        .environmentObject(viewModel)
        .task {
            await viewModel.loadCatalogIfNeeded()
            await viewModel.refreshAllEvents()
        }
    }
}

#Preview {
    ContentView()
}
