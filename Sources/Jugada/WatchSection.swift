import Foundation

// MARK: - WatchSection / Item (the generic render + notify unit)
//
// Every connector produces `[WatchSection]`. In Slice 1a only the notify path consumes these
// (the chess panel still renders from the typed `Snapshot`); generic panel rendering and
// the JSON connector arrive in 1b.

public struct WatchSection {
    public var id: String          // stable, e.g. "chess.broadcasts" — keys the seen/last-value store
    public var title: String
    public var items: [Item]
    public var notify: Notify

    public init(id: String, title: String, items: [Item], notify: Notify) {
        self.id = id; self.title = title; self.items = items; self.notify = notify
    }
}

public struct Item {
    public var title: String
    public var detail: String? = nil
    public var url: String? = nil
    public var status: String? = nil
    public var dot: Bool = false
    public var identity: String? = nil   // feeds `appears` diffing (e.g. a broadcast url)
    public var value: Double? = nil      // feeds threshold rules
    public var snippet: String? = nil    // reserved for a future on-device summarizer (unused in core)

    public init(title: String, detail: String? = nil, url: String? = nil, status: String? = nil,
                dot: Bool = false, identity: String? = nil, value: Double? = nil, snippet: String? = nil) {
        self.title = title; self.detail = detail; self.url = url; self.status = status
        self.dot = dot; self.identity = identity; self.value = value; self.snippet = snippet
    }
}

/// How a section participates in notifications. Display-only sections are `.off`.
public enum Notify {
    case off
    case appears(newItemTitle: String)   // banner title for a newly-seen item; body = the item's title
    case threshold(RuleType, Double)
}
