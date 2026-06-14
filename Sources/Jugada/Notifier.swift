import Foundation
import UserNotifications

/// Local notifications for new live events. Each refresh diffs the current
/// broadcasts against what we saw last time; anything new gets a banner. The
/// first successful fetch seeds the seen-set silently, so we don't fanfare
/// every event that was already running when the app launched.
enum Notifier {
    private static let seenKey = "jugada.seenBroadcasts"
    private static let seededKey = "jugada.broadcastsSeeded"

    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func handle(_ broadcasts: [Broadcast]) {
        let ud = UserDefaults.standard
        let seen = Set(ud.stringArray(forKey: seenKey) ?? [])
        if ud.bool(forKey: seededKey) {
            for event in broadcasts where !seen.contains(event.url) {
                post(title: "New live event", body: event.name, url: event.url)
            }
        }
        ud.set(broadcasts.map(\.url), forKey: seenKey)
        ud.set(true, forKey: seededKey)
    }

    private static func post(title: String, body: String, url: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["url": url]
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
