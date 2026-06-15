import Foundation

/// The generic contract every data source implements. Chess is the only connector in
/// Slice 1a (`ChessConnector`); the generic JSON connector arrives in 1b. A connector just
/// turns a poll into `[WatchSection]` — it knows nothing about notifications or the panel.
public protocol Connector {
    var id: String { get }
    var displayName: String { get }
    func poll() async -> [WatchSection]
}
