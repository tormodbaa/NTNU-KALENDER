import Foundation

extension Calendar {
    /// Mandag-basert kalender, slik norske ukeplaner forventes å se ut.
    ///
    /// Lagret som `static let` (ikke en computed property) med vilje: `Calendar` med
    /// egen locale er dyr å konstruere, og denne brukes i `hourFraction`, `startOfDay()`
    /// osv. som kalles for hver eneste hendelse hver gang kalenderen tegnes. Å lage en
    /// ny kalender per kall var en av hovedårsakene til at dag-bytte hakket.
    static let ntnu: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "nb_NO")
        calendar.firstWeekday = 2
        return calendar
    }()
}

/// `DateFormatter` er notorisk dyr å opprette (flere millisekunder), og
/// `Date.formatted(_:)` under ble tidligere kalt med en ny formatter hver gang —
/// for hver hendelse, hver overskrift, hver gang SwiftUI tegnet på nytt. Cache én
/// formatter per format-streng i stedet. `string(from:)` er trådsikker etter at
/// formatteren er ferdig konfigurert.
private final class DateFormatterCache: @unchecked Sendable {
    static let shared = DateFormatterCache()

    private var formatters: [String: DateFormatter] = [:]
    private let lock = NSLock()

    func formatter(for format: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = formatters[format] {
            return existing
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.calendar = Calendar.ntnu
        formatter.dateFormat = format
        formatters[format] = formatter
        return formatter
    }
}

extension Date {
    /// 1 = mandag ... 7 = søndag.
    var isoWeekday: Int {
        let raw = Calendar.ntnu.component(.weekday, from: self)
        return raw == 1 ? 7 : raw - 1
    }

    var weekOfYear: Int {
        Calendar.ntnu.component(.weekOfYear, from: self)
    }

    func startOfDay() -> Date {
        Calendar.ntnu.startOfDay(for: self)
    }

    func addingDays(_ days: Int) -> Date {
        Calendar.ntnu.date(byAdding: .day, value: days, to: self) ?? self
    }

    func mondayOfWeek() -> Date {
        let weekday = isoWeekday
        return addingDays(-(weekday - 1)).startOfDay()
    }

    var hourFraction: Double {
        let comps = Calendar.ntnu.dateComponents([.hour, .minute], from: self)
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    func formatted(_ format: String) -> String {
        DateFormatterCache.shared.formatter(for: format).string(from: self)
    }
}
