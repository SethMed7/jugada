import Foundation

/// What one refresh produces. `chess` is the typed snapshot the chess skin renders from;
/// `sections` is the generic view every connector contributes (just chess's in 1a).
public struct EngineResult {
    public let chess: Snapshot?
    public let sections: [Section]
}

/// The watch engine: poll connectors → run the (no-op) reasoning hook → evaluate rules →
/// post notifications. It owns the orchestration that used to live inline in
/// `AppDelegate.refresh()`. Local-first: it touches only the connectors' own fetches and
/// `UserDefaults` — no new outbound calls, nothing leaves the machine.
public final class Engine {
    /// Chess is the default skin, driven concretely so the panel keeps its typed snapshot.
    public let chess = ChessConnector()

    // Slice 1b: generic connectors (e.g. GenericJSONConnector reading Config.watchers) get
    // appended here and polled via `poll()`, their sections merged into the result below.

    private let reasoning: ReasoningHook = NoopReasoningHook()

    public init() {}

    public func refresh() async -> EngineResult {
        let snapshot = await chess.fetch()
        var sections = chess.sections(from: snapshot)
        // 1b: for connector in extra { sections += await connector.poll() }

        sections = await reasoning.process(sections)

        for notification in RuleEvaluator.evaluate(sections) {
            Notifier.post(notification)
        }

        return EngineResult(chess: snapshot, sections: sections)
    }
}

// MARK: - Reasoning seam (knight+)
//
// The post-poll hook where a future *local, on-device* model could filter, summarize, or
// soft-match items before notifications fire. The core ships the identity function — no
// model, no external calls. See DESIGN.md (knight+ stays on-device by default).
public protocol ReasoningHook {
    func process(_ sections: [Section]) async -> [Section]
}

public struct NoopReasoningHook: ReasoningHook {
    public init() {}
    public func process(_ sections: [Section]) async -> [Section] { sections }
}
