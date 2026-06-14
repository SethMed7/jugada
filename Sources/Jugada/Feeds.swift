import Foundation

// MARK: - Display models

public struct Puzzle {
    public let title: String    // "Daily puzzle"
    public let detail: String   // "rating 1746 · endgame, sacrifice" (lichess) or the chess.com title
    public let url: String
}

public struct Broadcast {
    public let name: String
    public let url: String
}

public struct Hero {
    public let username: String
    public let lastSeen: String?  // nil when this hero's fetch failed
    public let url: String?
}

/// One snapshot consumed by both the menu builder and `--check`.
/// A failed section degrades to .failure — never throws, never crashes.
public struct Snapshot {
    public let puzzle: Result<Puzzle, Error>
    public let broadcasts: Result<[Broadcast], Error>
    public let heroes: Result<[Hero], Error>
}

// MARK: - Feeds

public enum Feeds {
    private static let timeout: TimeInterval = 10
    private static let userAgent = "jugada/0.1 (github.com/SethMed7/jugada)"

    public static func snapshot() async -> Snapshot {
        let cfg = Config.load()
        async let puzzle = safePuzzle(source: cfg.puzzleSource ?? "lichess")
        async let broadcasts = safeBroadcasts()
        async let heroes = safeHeroes(cfg.heroes)
        return await Snapshot(puzzle: puzzle, broadcasts: broadcasts, heroes: heroes)
    }

    private static func safePuzzle(source: String) async -> Result<Puzzle, Error> {
        do { return .success(try await dailyPuzzle(source: source)) } catch { return .failure(error) }
    }

    private static func safeBroadcasts() async -> Result<[Broadcast], Error> {
        do { return .success(try await broadcasts()) } catch { return .failure(error) }
    }

    /// The heroes section only counts as failed when every hero is unreachable.
    private static func safeHeroes(_ usernames: [String]) async -> Result<[Hero], Error> {
        let heroes = await fetchHeroes(usernames)
        if !heroes.isEmpty && heroes.allSatisfy({ $0.lastSeen == nil }) {
            return .failure(URLError(.cannotConnectToHost))
        }
        return .success(heroes)
    }

    // MARK: lichess

    private struct DailyPuzzleResponse: Decodable {
        struct Inner: Decodable {
            let rating: Int
            let themes: [String]
        }
        let puzzle: Inner
    }

    static func dailyPuzzle(source: String = "lichess") async throws -> Puzzle {
        let s = source.lowercased()
        if s == "chess.com" || s == "chesscom" { return try await chessComPuzzle() }
        return try await lichessPuzzle()
    }

    static func lichessPuzzle() async throws -> Puzzle {
        let data = try await get(URL(string: "https://lichess.org/api/puzzle/daily")!)
        let decoded = try JSONDecoder().decode(DailyPuzzleResponse.self, from: data)
        let themes = decoded.puzzle.themes.prefix(4).joined(separator: ", ")
        let detail = themes.isEmpty ? "rating \(decoded.puzzle.rating)"
                                    : "rating \(decoded.puzzle.rating) · \(themes)"
        return Puzzle(title: "Daily puzzle", detail: detail, url: "https://lichess.org/training/daily")
    }

    // MARK: chess.com puzzle

    private struct ChessComPuzzleResponse: Decodable {
        let title: String
        let url: String
    }

    static func chessComPuzzle() async throws -> Puzzle {
        let data = try await get(URL(string: "https://api.chess.com/pub/puzzle")!, userAgent: userAgent)
        let decoded = try JSONDecoder().decode(ChessComPuzzleResponse.self, from: data)
        let detail = decoded.title.isEmpty ? "today's puzzle" : decoded.title
        return Puzzle(title: "Daily puzzle", detail: detail, url: decoded.url)
    }

    private struct BroadcastLine: Decodable {
        // Lichess has changed this shape before — decode defensively, prefer tour.url.
        struct Tour: Decodable {
            let name: String
            let url: String?
            let slug: String?
            let id: String?
        }
        let tour: Tour
    }

    static func broadcasts() async throws -> [Broadcast] {
        let data = try await get(URL(string: "https://lichess.org/api/broadcast?nb=5")!,
                                 accept: "application/x-ndjson")
        // NDJSON: one JSON object per line; a bad line is skipped, not fatal.
        let decoder = JSONDecoder()
        var result: [Broadcast] = []
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let decoded = try? decoder.decode(BroadcastLine.self, from: lineData)
            else { continue }
            let tour = decoded.tour
            let urlString: String
            if let url = tour.url {
                urlString = url
            } else if let slug = tour.slug, let id = tour.id {
                urlString = "https://lichess.org/broadcast/\(slug)/\(id)"
            } else {
                continue
            }
            guard URL(string: urlString) != nil else { continue }
            result.append(Broadcast(name: tour.name, url: urlString))
            if result.count == 5 { break }
        }
        return result
    }

    // MARK: chess.com

    private struct PlayerResponse: Decodable {
        let username: String
        let last_online: Int
        let url: String
    }

    static func fetchHeroes(_ usernames: [String]) async -> [Hero] {
        await withTaskGroup(of: (Int, Hero).self) { group in
            for (index, username) in usernames.enumerated() {
                group.addTask { (index, await hero(username)) }
            }
            var indexed: [(Int, Hero)] = []
            for await pair in group { indexed.append(pair) }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// One failed hero shows "— offline"; it never sinks the section.
    static func hero(_ username: String) async -> Hero {
        let fallbackURL = "https://www.chess.com/member/\(username)"
        guard let url = URL(string: "https://api.chess.com/pub/player/\(username)"),
              let data = try? await get(url, userAgent: userAgent),
              let decoded = try? JSONDecoder().decode(PlayerResponse.self, from: data)
        else {
            return Hero(username: username, lastSeen: nil, url: nil)
        }
        return Hero(username: decoded.username,
                    lastSeen: relativeTime(epoch: decoded.last_online),
                    url: decoded.url.isEmpty ? fallbackURL : decoded.url)
    }

    private static func relativeTime(epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: shared request

    private static func get(_ url: URL,
                            accept: String? = nil,
                            userAgent: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        if let accept { request.setValue(accept, forHTTPHeaderField: "Accept") }
        // chess.com returns 403 without a User-Agent.
        if let userAgent { request.setValue(userAgent, forHTTPHeaderField: "User-Agent") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
