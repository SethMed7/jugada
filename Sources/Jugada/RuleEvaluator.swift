import Foundation

/// What the engine decided should be notified. The evaluator only *decides*; `Notifier`
/// posts. `watcherId`/`value` ride along in the banner payload as the "why did this fire?"
/// seam for a future knight+ action.
public struct PendingNotification {
    public let title: String
    public let body: String
    public let url: String?
    public let watcherId: String
    public let value: Double?
}

/// The generalized successor to the old `Notifier.handle`. Two deterministic rule families,
/// both edge-triggered and both silently seeded on first observation so launching the app
/// never produces a banner storm for things that were already true.
///
///  - `appears`    — set-membership diff (today's broadcast logic, verbatim).
///  - thresholds   — fire only on the *crossing*, not every poll the condition holds.
///
/// All state lives in `UserDefaults`; nothing leaves the machine.
public enum RuleEvaluator {
    public static func evaluate(_ sections: [Section]) -> [PendingNotification] {
        let ud = UserDefaults.standard
        var pending: [PendingNotification] = []

        for section in sections {
            switch section.notify {
            case .off:
                continue

            case .appears(let newItemTitle):
                let seenKey = seenKey(section.id), seededKey = seededKey(section.id)
                let seen = Set(ud.stringArray(forKey: seenKey) ?? [])
                // Seed silently the first time; only banner once we've established a baseline.
                if ud.bool(forKey: seededKey) {
                    for item in section.items {
                        guard let id = item.identity, !seen.contains(id) else { continue }
                        pending.append(PendingNotification(title: newItemTitle, body: item.title,
                                                           url: item.url, watcherId: section.id, value: nil))
                    }
                }
                ud.set(section.items.compactMap { $0.identity }, forKey: seenKey)
                ud.set(true, forKey: seededKey)

            case .threshold(let type, let threshold):
                for item in section.items {
                    guard let now = item.value else { continue }
                    let key = lastValueKey(section.id, item)
                    let hasPrev = ud.object(forKey: key) != nil
                    let prev = ud.double(forKey: key)
                    ud.set(now, forKey: key)
                    guard hasPrev else { continue }   // silent seed on first observation
                    if crossed(type, prev: prev, now: now, threshold: threshold) {
                        pending.append(PendingNotification(title: item.title,
                                                           body: item.detail ?? format(now),
                                                           url: item.url, watcherId: section.id, value: now))
                    }
                }
            }
        }
        return pending
    }

    private static func crossed(_ type: RuleType, prev: Double, now: Double, threshold t: Double) -> Bool {
        switch type {
        case .above:   return prev < t && now >= t
        case .below:   return prev > t && now <= t
        case .changes: return now != prev
        case .equals:  return now == t && prev != t
        case .appears: return false
        }
    }

    // The chess broadcasts section keeps the original keys so existing installs keep their
    // seen-set and never re-seed; everything else is namespaced by section id.
    private static func seenKey(_ id: String) -> String {
        id == "chess.broadcasts" ? "jugada.seenBroadcasts" : "jugada.seen.\(id)"
    }
    private static func seededKey(_ id: String) -> String {
        id == "chess.broadcasts" ? "jugada.broadcastsSeeded" : "jugada.seeded.\(id)"
    }
    private static func lastValueKey(_ id: String, _ item: Item) -> String {
        "jugada.lastValue.\(id).\(item.identity ?? item.title)"
    }
    private static func format(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
}
