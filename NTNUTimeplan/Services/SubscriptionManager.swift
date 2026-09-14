import Foundation
import StoreKit

/// Håndterer det ene abonnementet appen selger: «NTNU Timeplan Årlig» (49 kr/år med
/// 7 dager gratis prøveperiode). Bygget på StoreKit 2 — ingen kvitteringsvalidering
/// på egen server nødvendig; Apple signerer transaksjonene og StoreKit verifiserer dem
/// lokalt (`VerificationResult.verified`).
///
/// Selve prisen, varigheten og prøveperioden konfigureres i App Store Connect (og i
/// `NTNUTimeplan.storekit` for lokal testing) — koden her leser dem derfra, så du kan
/// endre pris senere uten å slippe ny versjon.
@MainActor
final class SubscriptionManager: ObservableObject {
    /// Må stemme nøyaktig med produkt-ID-en i App Store Connect og `NTNUTimeplan.storekit`.
    static let yearlyProductID = "no.tormod.ntnutimeplan.annual"

    @Published private(set) var product: Product?
    @Published private(set) var isSubscribed = false
    /// `false` til første sjekk mot StoreKit er ferdig. Brukes for å ikke blinke opp
    /// betalingsmuren i et halvt sekund for brukere som allerede abonnerer.
    @Published private(set) var hasCheckedEntitlements = false
    /// Om denne Apple-ID-en fortsatt kan få gratis prøveperiode (Apple gir den bare én
    /// gang per abonnementsgruppe). Styrer om knappen sier «Start gratis prøveperiode»
    /// eller bare «Abonner».
    @Published private(set) var isEligibleForIntroOffer = true
    @Published private(set) var expirationDate: Date?
    @Published private(set) var willAutoRenew = true
    @Published private(set) var isPurchasing = false
    @Published private(set) var isLoadingProducts = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Oppstart

    func start() async {
        await refreshEntitlements()
        await loadProducts()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: [Self.yearlyProductID])
            product = products.first
            if let subscription = product?.subscription {
                isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
            }
            if product == nil {
                errorMessage = "Fant ikke abonnementet i App Store. Prøv igjen om litt."
            }
        } catch {
            errorMessage = "Kunne ikke hente prisen fra App Store. Sjekk nettforbindelsen og prøv igjen."
        }
    }

    // MARK: - Rettigheter

    /// Sjekker hva denne Apple-ID-en faktisk har tilgang til akkurat nå. Fungerer også
    /// uten nett — StoreKit cacher signerte transaksjoner lokalt på enheten.
    func refreshEntitlements() async {
        var active = false
        var latestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.yearlyProductID,
                  transaction.revocationDate == nil
            else { continue }
            active = true
            if let expiration = transaction.expirationDate {
                latestExpiration = max(latestExpiration ?? expiration, expiration)
            }
        }

        isSubscribed = active
        expirationDate = latestExpiration

        if active, let statuses = try? await product?.subscription?.status,
           let status = statuses.first,
           case .verified(let renewal) = status.renewalInfo {
            willAutoRenew = renewal.willAutoRenew
        }

        hasCheckedEntitlements = true
    }

    // MARK: - Kjøp

    func purchase() async {
        guard let product else {
            await loadProducts()
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "Apple kunne ikke bekrefte kjøpet. Prøv igjen, eller trykk «Gjenopprett kjøp»."
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                // F.eks. «Be om å kjøpe» (familiedeling) — kjøpet fullføres senere og
                // fanges opp av `listenForTransactionUpdates()`.
                errorMessage = "Kjøpet venter på godkjenning."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Kjøpet gikk ikke gjennom: \(error.localizedDescription)"
        }
    }

    /// Henter inn kjøp gjort på en annen enhet / etter reinstallering. Apple krever at
    /// en slik knapp finnes i appen for å godkjenne den i App Review.
    func restorePurchases() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "Kunne ikke gjenopprette kjøp: \(error.localizedDescription)"
        }
        await refreshEntitlements()
        if !isSubscribed, errorMessage == nil {
            errorMessage = "Fant ingen aktive abonnement på denne Apple-ID-en."
        }
    }

    // MARK: - Bakgrunnsoppdateringer

    /// Fornyelser, kanselleringer, refusjoner og kjøp fra andre enheter kommer inn her.
    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    // MARK: - Tekst til betalingsmuren

    /// F.eks. «49,00 kr/år».
    var priceLabel: String? {
        guard let product else { return nil }
        return "\(product.displayPrice)/år"
    }

    /// F.eks. «7 dager gratis» — lest fra tilbudet Apple faktisk har konfigurert, slik at
    /// teksten aldri lover noe annet enn det brukeren blir belastet for.
    var trialLabel: String? {
        guard isEligibleForIntroOffer,
              let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial
        else { return nil }
        let period = offer.period
        switch period.unit {
        case .day: return period.value == 1 ? "1 dag gratis" : "\(period.value) dager gratis"
        case .week: return period.value == 1 ? "7 dager gratis" : "\(period.value) uker gratis"
        case .month: return period.value == 1 ? "1 måned gratis" : "\(period.value) måneder gratis"
        case .year: return period.value == 1 ? "1 år gratis" : "\(period.value) år gratis"
        @unknown default: return "Gratis prøveperiode"
        }
    }
}
