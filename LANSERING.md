# NTNU Timeplan – veien til App Store

Rekkefølgen under er viktig: abonnementet må finnes i App Store Connect **før** du laster opp bygget, ellers finner ikke appen produktet og betalingsmuren viser «Fant ikke abonnementet».

Produkt-ID-en som er hardkodet i `SubscriptionManager.swift`: `no.tormod.ntnutimeplan.yearly`
Bundle ID: `no.tormod.ntnutimeplan` · Team: `24T86MDB5Y`

---

## 0. Test lokalt først (5 min)

1. Åpne prosjektet i Xcode. Filen `NTNUTimeplan.storekit` ligger i prosjektroten – hvis Xcode ikke viser den i navigatoren, dra den inn fra Finder (ikke huk av «Add to target»).
2. **Product → Scheme → Edit Scheme… → Run → Options → StoreKit Configuration:** velg `NTNUTimeplan.storekit`.
3. Kjør på simulator. Betalingsmuren skal vise «7 dager gratis, deretter 49,00 kr/år». Trykk «Start gratis prøveperiode» – simulatoren godkjenner uten Apple-ID.
4. **Debug → StoreKit → Manage Transactions** lar deg refundere/slette kjøpet for å teste betalingsmuren på nytt, og du kan sette «Time rate» i StoreKit-editoren slik at 1 uke går på sekunder for å teste utløp.
5. Fjern StoreKit-konfigurasjonen fra scheme igjen (sett til None) før du arkiverer – ellers går TestFlight-bygg mot den falske butikken.

Får Xcode ikke åpnet `.storekit`-filen: lag en ny via **File → New → File → StoreKit Configuration File**, huk av *Sync this file with an app in App Store Connect* når appen finnes der, så fylles alt inn automatisk.

---

## 1. App Store Connect – opprett appen

1. Gå til [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps → +**.
2. Plattform iOS, navn **NTNU Timeplan** (navnet må være ledig globalt – ha en reserve klar, f.eks. «Timeplan for NTNU»), primærspråk **Norwegian (Bokmål)**, Bundle ID `no.tormod.ntnutimeplan`, SKU f.eks. `ntnutimeplan-ios`.
3. Under **App Information** → Age Rating: svar nei på alt → 4+. Kategori: *Education* (sekundær: *Productivity*).

## 2. Betalte apper-avtalen (må være signert før abonnementet kan bli aktivt)

1. **Business → Agreements** (øverst) → **Paid Apps Agreement** → Request/Accept.
2. Fyll inn **bankkonto** (norsk IBAN funker), **skatteinfo** – for Norge er det «Certificate of Foreign Status of Beneficial Owner» (W-8BEN); velg *individual* om du selger som privatperson. Merk at Apple utbetaler først når du har passert ca. 100 kr, og at Apple tar 15 % (Small Business Program – meld deg inn under Agreements, gratis) i stedet for 30 %.
3. Status må bli **Active** før appen kan godkjennes med kjøp i.

## 3. Opprett abonnementet

1. Appen → **Monetization → Subscriptions → Create** (Subscription Group).
   - Reference Name: `NTNU Timeplan`
2. **+** i gruppen → nytt abonnement:
   - Reference Name: `Årlig`
   - **Product ID: `no.tormod.ntnutimeplan.yearly`** (nøyaktig – kan ikke endres etterpå)
3. Inne på abonnementet:
   - **Subscription Duration:** 1 Year
   - **Subscription Prices → +:** velg Norway som basisland, finn **49,00 kr** i lista (Apple har faste pristrinn; hvis 49 ikke finnes, velg 49,00 eller nærmeste). La Apple regne ut andre land automatisk.
   - **Introductory Offers → +:** alle land → *Free* → **1 week** → start i dag, ingen sluttdato. Dette er «første uke gratis».
   - **App Store Localization** (Norwegian Bokmål): Display Name `NTNU Timeplan Årlig`, Description `Alle emner, varsler og eksport – hele studieåret.`
   - **Review Information:** last opp et skjermbilde av betalingsmuren (kjør appen med StoreKit-fila, ta screenshot) og skriv en setning som «Årsabonnement som gir full tilgang til appen. 7 dager gratis prøveperiode.»
4. Gruppen: **Subscription Group Localization** → Bokmål, App Name for gruppen `NTNU Timeplan`.
5. Status skal stå som **Ready to Submit**. Abonnementet sendes inn sammen med første app-versjon (huk av under «In-App Purchases and Subscriptions» på versjonssiden).

## 4. Personvern og vilkår (Apple avviser uten disse)

Apple krever på betalingsmuren og i App Store-oppføringen:

- **Privacy Policy URL** – din egen side. Ferdig HTML ligger i `docs/personvern.html` (og `docs/index.html` som support-side). Publiser med GitHub Pages: push repoet → github.com/tormodbaa/NTNU-KALENDER → **Settings → Pages → Source: Deploy from a branch → main / `/docs`** → Save. Etter et par minutter ligger den på `https://tormodbaa.github.io/NTNU-KALENDER/personvern.html`, som allerede er satt i `PaywallView.privacyPolicyURL`. (Krever at repoet er offentlig, eller GitHub Pro. Alternativ: dra `docs/`-mappen inn på app.netlify.com/drop og bytt URL-en i koden.)
- **Terms of Use** – appen lenker til Apples standard-EULA, som er lov. Lim samme lenke inn i App Store Connect → App Information → *License Agreement* (behold standard) og i beskrivelsen: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`.
- **App Privacy** (App Store Connect → App Privacy): Appen samler ingen data. Velg «Data Not Collected». (Emnevalg og innstillinger lagres bare lokalt på enheten; NTNU-API-kall inneholder ingen persondata.)

## 5. Prosjektinnstillinger i Xcode før arkivering

- **Signing & Capabilities:** Team satt, Automatically manage signing. In-App Purchase er på for alle App ID-er som standard – du trenger ikke legge den til manuelt, men gjør det gjerne (+ Capability → In-App Purchase) så Xcode verifiserer det.
- **General → Version 1.0, Build 1.** Hvert nye TestFlight/App Store-bygg må ha høyere Build-nummer.
- Sett **iPhone-only** hvis du ikke vil teste på iPad (General → Supported Destinations, fjern iPad) – ellers må skjermbildene også finnes for iPad og appen reviewes på iPad.
- Scheme → StoreKit Configuration = **None**.

## 6. Bygg, TestFlight, innsending

1. Velg **Any iOS Device (arm64)** → **Product → Archive** → Organizer → **Distribute App → App Store Connect → Upload**.
2. Etter ~10–30 min dukker bygget opp under **TestFlight**. Legg til deg selv som intern tester, installer via TestFlight-appen. Her testes ekte kjøp i sandbox: du blir ikke belastet, og abonnementet «fornyes» hvert 1 time i sandbox (1 uke prøve = 3 min). Lag en **Sandbox Tester** under Users and Access → Sandbox om du vil teste med en annen Apple-ID.
3. **App Store → 1.0 Prepare for Submission:**
   - Skjermbilder: 6,7" (iPhone 15 Pro Max/16 Pro Max-simulator, 1290×2796) er obligatorisk; 6,5" kan Apple skalere fra 6,7". Ta 3–5: ukevisning, dagvisning, emnesøk, varslinger, betalingsmur.
   - Beskrivelse, nøkkelord («ntnu, timeplan, forelesning, trondheim, student, kalender»), support-URL (`https://tormodbaa.github.io/NTNU-KALENDER/`), markedsføringstekst.
   - **Velg bygget**, huk av abonnementet under In-App Purchases.
   - **App Review Information:** skriv til reviewer (på engelsk):
     > The app fetches public lecture schedules from NTNU's open API and shows them in a calendar. Full access requires a yearly subscription (7-day free trial). No account/login needed – tap "Start gratis prøveperiode" on the first screen to get in. Notes: UI is in Norwegian.
   - Export Compliance er allerede satt til «no non-exempt encryption» i prosjektet.
4. **Submit for Review.** Første review tar typisk 1–3 dager. Vanligste avslag for denne typen app: (a) betalingsmuren mangler pris/vilkår – løst i koden; (b) Paid Apps Agreement ikke aktiv – sjekk steg 2; (c) «Gjenopprett kjøp» mangler – finnes både på betalingsmuren og i Innstillinger.

## 7. Etter lansering

- Prisen kan endres i App Store Connect uten nytt bygg (eksisterende abonnenter varsles av Apple).
- **Sales and Trends / Subscriptions**-rapporten viser prøveperioder → betalende konvertering.
- Vurder å legge til en «Kjøp abonnement»-rad i Innstillinger som viser betalingsmuren igjen, hvis du senere åpner deler av appen gratis.
