import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @StateObject private var subscriptions = SubscriptionManager()

    var body: some View {
        TabView {
            ScheduleView()
                .tabItem { Label("Timeplan", systemImage: "calendar") }

            CourseSearchView()
                .tabItem { Label("Emner", systemImage: "magnifyingglass") }
        }
        .environmentObject(viewModel)
        .environmentObject(subscriptions)
        // Betalingsmuren ligger over hele appen til brukeren har et aktivt abonnement
        // (inkl. gratis prøveperiode). `fullScreenCover` kan ikke sveipes bort, og vi
        // venter på første StoreKit-sjekk slik at betalende brukere aldri ser den blinke.
        .fullScreenCover(isPresented: paywallPresented) {
            PaywallView().environmentObject(subscriptions)
        }
        .task {
            await subscriptions.start()
        }
        .task {
            await viewModel.loadCatalogIfNeeded()
            await viewModel.refreshAllEvents()
        }
    }

    private var paywallPresented: Binding<Bool> {
        Binding(
            get: { subscriptions.hasCheckedEntitlements && !subscriptions.isSubscribed },
            set: { _ in }
        )
    }
}

#Preview {
    ContentView()
}
