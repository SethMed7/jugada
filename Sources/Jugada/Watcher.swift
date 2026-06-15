import Foundation

// MARK: - Watcher (the keystone type)
//
// A Watcher is the single representation every "add a watch" path compiles down to:
// recipes, the visual click-to-pick picker, and — later, in knight+ — a natural-language
// `tell me when …` prompt. The reasoning seam is exactly this: `NL → Watcher` is a pure
// function whose output type already exists, so the model layer drops in without touching
// the engine. See DESIGN.md.
//
// Defined now to lock the type and keep `~/.jugada/config.json` forward-compatible. The
// generic JSON connector that *runs* these watchers arrives in Slice 1b; nothing in 1a
// consumes them beyond the (optional) `Config.watchers` field.

public struct Watcher: Codable {
    public var name: String
    public var icon: String?
    public var source: WatchSource
    public var extract: Extract
    public var rule: WatchRule
    public var display: Display
}

/// Where a watcher polls. The URL is always user-visible (a recipe's baked-in endpoint or a
/// link the user pasted) — knight never hides a call. `headers` is for a key the user owns.
public struct WatchSource: Codable {
    public var url: String
    public var headers: [String: String]?
    public var interval: Int?   // seconds; nil = use the app default
}

/// Which value to pull out of the fetched JSON, as a dot-path (e.g. "bitcoin.usd").
public struct Extract: Codable {
    public var path: String
}

/// The deterministic rule the engine evaluates — no reasoning required.
public struct WatchRule: Codable {
    public var type: RuleType
    public var value: Double?   // the threshold; nil for `appears`/`changes`
}

public enum RuleType: String, Codable {
    case appears   // a new item showed up (set-membership diff)
    case above     // value crossed up through `value`
    case below     // value crossed down through `value`
    case changes   // value differs from last poll
    case equals    // value became exactly `value`
}

/// What the row / banner says when this watcher fires.
public struct Display: Codable {
    public var title: String
    public var detail: String?
    public var link: String?
}
