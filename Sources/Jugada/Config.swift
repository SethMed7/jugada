import Foundation

/// User config at ~/.jugada/config.json — created with defaults on first run.
struct Config: Codable {
    var heroes: [String]
    /// The one data source for everything — "lichess" (default) or "chess.com".
    /// Governs the puzzle, the live section, and hero tracking.
    var source: String?
    /// Legacy key from when only the puzzle had a source; read as a fallback.
    var puzzleSource: String?

    /// Resolved source, honoring the legacy `puzzleSource` key.
    var effectiveSource: String { source ?? puzzleSource ?? "lichess" }

    static let defaults = Config(heroes: ["magnuscarlsen", "hikaru"], source: "lichess", puzzleSource: nil)

    static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".jugada")
            .appendingPathComponent("config.json")
    }

    static func load() -> Config {
        guard let data = try? Data(contentsOf: fileURL) else {
            writeDefaults()
            return defaults
        }
        // Malformed JSON falls back to defaults in memory; never overwrite the user's file.
        return (try? JSONDecoder().decode(Config.self, from: data)) ?? defaults
    }

    /// Persist the chosen source (from the panel toggle), keeping heroes.
    static func setSource(_ value: String) {
        var config = load()
        config.source = value
        config.puzzleSource = nil
        write(config)
    }

    private static func writeDefaults() { write(defaults) }

    private static func write(_ config: Config) {
        let url = fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config) {
            try? data.write(to: url)
        }
    }
}
