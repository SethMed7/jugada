import Foundation

/// Chess — the flagship connector and the default skin. It wraps the existing chess fetch
/// (`Feeds.snapshot()`, unchanged) and maps the typed `Snapshot` into generic `[WatchSection]`
/// for the notification path. The typed `Snapshot` itself is handed straight to the panel
/// by the `Engine`, so the chess skin renders exactly as it does today — a skin is allowed
/// a richer concrete output than a generic connector.
public final class ChessConnector: Connector {
    public let id = "chess"
    public let displayName = "Chess"

    /// Mirrors the panel's Source toggle (set by `AppDelegate`). Drives the notify decision:
    /// only lichess broadcasts are notification-worthy "events" — chess.com's live section is
    /// streamers, which come and go and would be noise.
    public var source: Source = .lichess

    public init() {}

    public func poll() async -> [WatchSection] {
        sections(from: await fetch())
    }

    /// The typed snapshot the chess skin renders from. `Feeds.snapshot()` reads the source
    /// from config itself, so this stays in lockstep with `source` (both set on toggle).
    public func fetch() async -> Snapshot {
        await Feeds.snapshot()
    }

    public func sections(from snapshot: Snapshot) -> [WatchSection] {
        var out: [WatchSection] = []

        if case .success(let puzzle) = snapshot.puzzle {
            out.append(WatchSection(id: "chess.puzzle", title: "Puzzle",
                               items: [Item(title: puzzle.title, detail: puzzle.detail, url: puzzle.url)],
                               notify: .off))
        }

        // Only emit the broadcasts section on success — on failure we leave it out entirely so
        // the seen-set is never overwritten (matching today, where a failed fetch skips notify).
        if case .success(let tours) = snapshot.broadcasts {
            let notify: Notify = source == .lichess ? .appears(newItemTitle: "New live event") : .off
            out.append(WatchSection(id: "chess.broadcasts",
                               title: source == .lichess ? "Live events" : "Live streamers",
                               items: tours.map { Item(title: $0.name, url: $0.url, dot: true, identity: $0.url) },
                               notify: notify))
        }

        if case .success(let heroes) = snapshot.heroes {
            out.append(WatchSection(id: "chess.heroes", title: "Heroes",
                               items: heroes.map { Item(title: $0.username, detail: $0.status, url: $0.url) },
                               notify: .off))
        }

        return out
    }
}
