import Foundation
import UserNotifications

/// Planlegger lokale varsler et gitt antall minutter før hver undervisningstime.
/// Alle varsler får en identifiserbar prefiks slik at de trygt kan fjernes og
/// erstattes samlet når timeplanen endrer seg.
enum NotificationScheduler {
    private static let idPrefix = "ntnu-event-"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func reschedule(
        events: [ScheduleEvent],
        courses: [SelectedCourse],
        leadMinutes: Int,
        mutedCourseCodes: Set<String>,
        mutedKinds: Set<EventKind>
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ourIDs = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ourIDs)

        let nameByCode = Dictionary(uniqueKeysWithValues: courses.map { ($0.code, $0.name) })
        let now = Date()

        let relevantEvents = events.filter {
            !mutedCourseCodes.contains($0.courseCode) && !mutedKinds.contains($0.kind) && !$0.isExtendedSession
        }

        for event in relevantEvents {
            guard let fireDate = Calendar.current.date(byAdding: .minute, value: -leadMinutes, to: event.start),
                  fireDate > now
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(event.courseCode) \(nameByCode[event.courseCode] ?? "")"
            let roomText = event.rooms.first.map { " i \($0.displayName)" } ?? ""
            content.body = "\(event.title) kl. \(event.start.formatted("HH:mm"))\(roomText)"
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: idPrefix + event.id, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ourIDs = requests.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ourIDs)
        }
    }
}
