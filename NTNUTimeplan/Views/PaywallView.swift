import SwiftUI

/// Betalingsmuren som vises når brukeren ikke har et aktivt abonnement. Teksten om pris,
/// varighet, automatisk fornyelse og lenkene til vilkår/personvern er ikke pynt — Apple
/// krever alt dette synlig på selve kjøpsskjermen for å godkjenne appen (App Review
/// Guidelines 3.1.2), og teksten «7 dager gratis» skal komme fra StoreKit, ikke være
/// hardkodet, slik at den alltid stemmer med det Apple faktisk belaster.
struct PaywallView: View {
    @EnvironmentObject var subscriptions: SubscriptionManager

    /// Publiseres via GitHub Pages fra `docs/`-mappen i dette repoet (se LANSERING.md).
    /// Må være samme URL som oppgis som Privacy Policy URL i App Store Connect. Apples
    /// standard-EULA er godkjent å bruke som «Terms of Use».
    static let privacyPolicyURL = URL(string: "https://tormodbaa.github.io/NTNU-KALENDER/personvern.html")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                features
                pricing
                actions
                legal
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            if subscriptions.product == nil {
                await subscriptions.loadProducts()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("NTNU Timeplan")
                .font(.largeTitle.bold())
            Text("Hele semesteret ditt, samlet på ett sted.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            FeatureRow(symbol: "magnifyingglass", title: "Alle NTNU-emner", detail: "Søk opp emnene dine eller importer hele studieprogrammet.")
            FeatureRow(symbol: "calendar.day.timeline.left", title: "Uke- og dagvisning", detail: "Se kollisjoner, rom og MazeMap-lenke direkte i kalenderen.")
            FeatureRow(symbol: "bell.badge", title: "Varsel før timen", detail: "Velg hvor lenge før, og hvilke emner og timetyper.")
            FeatureRow(symbol: "square.and.arrow.up", title: "Eksport", detail: "Legg timeplanen rett i Apple Kalender eller del som .ics.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var pricing: some View {
        if let price = subscriptions.priceLabel {
            VStack(spacing: 4) {
                if let trial = subscriptions.trialLabel {
                    Text(trial)
                        .font(.title2.bold())
                    Text("deretter \(price)")
                        .foregroundStyle(.secondary)
                } else {
                    Text(price)
                        .font(.title2.bold())
                }
                Text("Kan sies opp når som helst i Innstillinger på iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } else if subscriptions.isLoadingProducts {
            ProgressView("Henter pris fra App Store …")
        } else {
            VStack(spacing: 8) {
                Text(subscriptions.errorMessage ?? "Kunne ikke hente prisen fra App Store.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Prøv igjen") {
                    Task { await subscriptions.loadProducts() }
                }
                .font(.footnote.weight(.semibold))
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await subscriptions.purchase() }
            } label: {
                Group {
                    if subscriptions.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(subscriptions.trialLabel != nil ? "Start gratis prøveperiode" : "Abonner")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(subscriptions.product == nil || subscriptions.isPurchasing)

            Button("Gjenopprett kjøp") {
                Task { await subscriptions.restorePurchases() }
            }
            .font(.subheadline)
            .disabled(subscriptions.isPurchasing)

            if let message = subscriptions.errorMessage, subscriptions.product != nil {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var legal: some View {
        VStack(spacing: 10) {
            Text(disclosure)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Vilkår for bruk", destination: Self.termsOfUseURL)
                Link("Personvern", destination: Self.privacyPolicyURL)
            }
            .font(.caption)
        }
    }

    private var disclosure: String {
        let price = subscriptions.priceLabel ?? "årsprisen"
        var text = "Abonnementet fornyes automatisk for \(price) til det sies opp. "
        if subscriptions.trialLabel != nil {
            text += "Prøveperioden er gratis; belastningen skjer først når den er over, og du kan si opp før det uten å betale noe. "
        }
        text += "Belastes Apple-ID-kontoen din ved bekreftelse. Si opp minst 24 timer før perioden utløper for å unngå fornyelse. Administreres under Abonnementer i Innstillinger på enheten."
        return text
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PaywallView().environmentObject(SubscriptionManager())
}
