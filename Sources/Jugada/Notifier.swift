import Foundation
import UserNotifications

/// The macOS notification layer: request permission, and post a banner. The *decision* of
/// what to notify now lives in `RuleEvaluator`; this file only delivers what it's handed.
enum Notifier {
    static func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func post(_ notification: PendingNotification) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        // Payload carries the watcher id + value (the "why did this fire?" seam) alongside
        // the url that the tap handler in AppDelegate opens.
        var info: [String: Any] = ["watcherId": notification.watcherId]
        if let url = notification.url { info["url"] = url }
        if let value = notification.value { info["value"] = value }
        content.userInfo = info
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
