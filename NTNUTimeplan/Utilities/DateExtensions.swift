import Foundation

extension Calendar {
    /// Mandag-basert kalender, slik norske ukeplaner forventes å se ut.
    static var ntnu: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "nb_NO")
        calendar.firstWeekday = 2
        return calendar
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}
