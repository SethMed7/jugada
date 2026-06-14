import Foundation

/// User config at ~/.jugada/config.json — created with defaults on first run.
struct Config: Codable {
    var heroes: [String]
    /// Daily-puzzle source: "lichess" (default) or "chess.com". Optional so older
    /// config files without the key still decode.
    var puzzleSource: String?

    static let defaults = Config(heroes: ["magnuscarlsen", "hikaru"], puzzleSource: "lichess")

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

    private static func writeDefaults() {
        let url = fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(defaults) {
            try? data.write(to: url)
        }
    }
}
