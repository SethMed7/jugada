import Foundation

/// Runs the user's generic JSON watches (`Config.watchers`): fetch a URL, pull one value
/// out by dot-path, and turn the configured rule into a notify-eligible `WatchSection`. This is
/// the connector that proves knight is general — chess is just the default skin.
///
/// Slice 1b supports **numeric** values (a price, a count, a rating) with the threshold
/// rules (`above` / `below` / `changes` / `equals`). String-valued and array (`appears`)
/// sources are a later slice.
///
/// Local-first / private: a request goes ONLY to the user-configured URL, carries only a
/// generic User-Agent plus any header the user supplied (for a key they own), and nothing
/// else. A failed or non-numeric fetch degrades to an offline row — it never notifies and
/// never crashes.
public final class GenericJSONConnector: Connector {
    public let id = "watchers"
    public let displayName = "Watchers"

    private static let timeout: TimeInterval = 10
    private static let userAgent = "jugada/0.1 (github.com/SethMed7/jugada)"

    public init() {}

    public func poll() async -> [WatchSection] {
        let watchers = Config.load().watchers ?? []
        guard !watchers.isEmpty else { return [] }
        // Poll concurrently, preserving config order (same pattern as Feeds' hero lookup).
        return await withTaskGroup(of: (Int, WatchSection).self) { group in
            for (index, watcher) in watchers.enumerated() {
                group.addTask { (index, await Self.section(for: watcher)) }
            }
            var indexed: [(Int, WatchSection)] = []
            for await pair in group { indexed.append(pair) }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    static func sectionId(_ watcher: Watcher) -> String { "watch.\(watcher.name)" }

    static func section(for watcher: Watcher) async -> WatchSection {
        let id = sectionId(watcher)
        guard let value = await fetchValue(watcher) else {
            return WatchSection(id: id, title: watcher.name,
                           items: [Item(title: watcher.display.title, detail: "— offline",
                                        url: watcher.display.link, identity: watcher.name)],
                           notify: .off)
        }
        let item = Item(title: watcher.display.title,
                        detail: detailText(watcher, value),
                        url: watcher.display.link,
                        identity: watcher.name,
                        value: value)
        return WatchSection(id: id, title: watcher.name, items: [item], notify: notify(for: watcher))
    }

    private static func notify(for watcher: Watcher) -> Notify {
        switch watcher.rule.type {
        case .above, .below, .equals:
            guard let target = watcher.rule.value else { return .off }   // threshold needs a target
            return .threshold(watcher.rule.type, target)
        case .changes:
            return .threshold(.changes, 0)
        case .appears:
            return .off   // a single value can't "appear"; array sources are a later slice
        }
    }

    private static func detailText(_ watcher: Watcher, _ value: Double) -> String {
        guard let template = watcher.display.detail else { return format(value) }
        return template.replacingOccurrences(of: "{value}", with: format(value))
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    // MARK: fetch + extract

    static func fetchValue(_ watcher: Watcher) async -> Double? {
        guard let url = URL(string: watcher.source.url) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (key, value) in watcher.source.headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return extractNumber(from: data, path: watcher.extract.path)
    }

    /// Walk a dot-path into the JSON (object keys or array indices) and read the leaf as a
    /// number. Numeric strings (some APIs quote their numbers) are accepted.
    static func extractNumber(from data: Data, path: String) -> Double? {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var current: Any? = root
        for key in path.split(separator: ".") {
            if let dict = current as? [String: Any] {
                current = dict[String(key)]
            } else if let array = current as? [Any], let index = Int(key), array.indices.contains(index) {
                current = array[index]
            } else {
                return nil
            }
        }
        if let number = current as? NSNumber { return number.doubleValue }
        if let string = current as? String { return Double(string) }
        return nil
    }
}
