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
    public let status: String?  // "last seen 2h ago" (chess.com) / "online" / "playing now" (lichess); nil = unavailable
    public let url: String?
}

/// One snapshot consumed by both the menu builder and `--check`.
/// A failed section degrades to .failure — never throws, never crashes.
public struct Snapshot {
    public let puzzle: Result<Puzzle, Error>
    public let broadcasts: Result<[Broadcast], Error>
    public let heroes: Result<[Hero], Error>
}

/// Where every section pulls from. The panel's toggle flips this for the whole
/// app — puzzle, live, and tracking all follow the one source.
public enum Source: String {
    case lichess, chesscom
    public static func from(_ raw: String?) -> Source {
        let v = (raw ?? "lichess").lowercased()
        return (v == "chess.com" || v == "chesscom") ? .chesscom : .lichess
    }
}

// MARK: - Feeds

public enum Feeds {
    private static let timeout: TimeInterval = 10
    private static let userAgent = "jugada/0.1 (github.com/SethMed7/jugada)"

    public static func snapshot() async -> Snapshot {
        let cfg = Config.load()
        let source = Source.from(cfg.effectiveSource)
        async let puzzle = safePuzzle(source)
        async let live = safeLive(source)
        async let heroes = safeHeroes(source, cfg.heroes)
        return await Snapshot(puzzle: puzzle, broadcasts: live, heroes: heroes)
    }

    private static func safePuzzle(_ source: Source) async -> Result<Puzzle, Error> {
        do { return .success(try await dailyPuzzle(source)) } catch { return .failure(error) }
    }

    private static func safeLive(_ source: Source) async -> Result<[Broadcast], Error> {
        do { return .success(try await live(source)) } catch { return .failure(error) }
    }

    /// The heroes section only counts as failed when every hero is unreachable.
    private static func safeHeroes(_ source: Source, _ usernames: [String]) async -> Result<[Hero], Error> {
        let heroes = source == .chesscom ? await chessComHeroes(usernames) : await lichessHeroes(usernames)
        if !heroes.isEmpty && heroes.allSatisfy({ $0.status == nil }) {
            return .failure(URLError(.cannotConnectToHost))
        }
        return .success(heroes)
    }

    // MARK: puzzle

    static func dailyPuzzle(_ source: Source) async throws -> Puzzle {
        if source == .chesscom { return try await chessComPuzzle() }
        return try await lichessPuzzle()
    }

    private struct DailyPuzzleResponse: Decodable {
        struct Inner: Decodable { let rating: Int; let themes: [String] }
        let puzzle: Inner
    }

    static func lichessPuzzle() async throws -> Puzzle {
        let data = try await get(URL(string: "https://lichess.org/api/puzzle/daily")!)
        let decoded = try JSONDecoder().decode(DailyPuzzleResponse.self, from: data)
        let themes = decoded.puzzle.themes.prefix(4).joined(separator: ", ")
        let detail = themes.isEmpty ? "rating \(decoded.puzzle.rating)"
                                    : "rating \(decoded.puzzle.rating) · \(themes)"
        return Puzzle(title: "Daily puzzle", detail: detail, url: "https://lichess.org/training/daily")
    }

    private struct ChessComPuzzleResponse: Decodable { let title: String; let url: String }

    static func chessComPuzzle() async throws -> Puzzle {
        let data = try await get(URL(string: "https://api.chess.com/pub/puzzle")!, userAgent: userAgent)
        let decoded = try JSONDecoder().decode(ChessComPuzzleResponse.self, from: data)
        let detail = decoded.title.isEmpty ? "today's puzzle" : decoded.title
        return Puzzle(title: "Daily puzzle", detail: detail, url: decoded.url)
    }

    // MARK: live

    static func live(_ source: Source) async throws -> [Broadcast] {
        if source == .chesscom { return try await chessComLive() }
        return try await broadcasts()
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

    // chess.com has no public broadcast feed; its closest "live now" data is the
    // streamers list, so on chess.com the Live section shows who's streaming.
    private struct StreamersResponse: Decodable {
        struct Streamer: Decodable {
            let username: String
            let url: String?
            let twitch_url: String?
            let is_live: Bool?
        }
        let streamers: [Streamer]
    }

    static func chessComLive() async throws -> [Broadcast] {
        let data = try await get(URL(string: "https://api.chess.com/pub/streamers")!, userAgent: userAgent)
        let decoded = try JSONDecoder().decode(StreamersResponse.self, from: data)
        var result: [Broadcast] = []
        for streamer in decoded.streamers where streamer.is_live == true {
            guard let link = streamer.twitch_url ?? streamer.url, URL(string: link) != nil else { continue }
            result.append(Broadcast(name: "\(streamer.username) — live", url: link))
            if result.count == 5 { break }
        }
        return result
    }

    // MARK: heroes / tracking

    private struct PlayerResponse: Decodable {
        let username: String
        let last_online: Int
        let url: String
    }

    static func chessComHeroes(_ usernames: [String]) async -> [Hero] {
        await withTaskGroup(of: (Int, Hero).self) { group in
            for (index, username) in usernames.enumerated() {
                group.addTask { (index, await chessComHero(username)) }
            }
            var indexed: [(Int, Hero)] = []
            for await pair in group { indexed.append(pair) }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    /// One failed hero shows "offline"; it never sinks the section.
    static func chessComHero(_ username: String) async -> Hero {
        let fallbackURL = "https://www.chess.com/member/\(username)"
        guard let url = URL(string: "https://api.chess.com/pub/player/\(username)"),
              let data = try? await get(url, userAgent: userAgent),
              let decoded = try? JSONDecoder().decode(PlayerResponse.self, from: data)
        else {
            return Hero(username: username, status: nil, url: nil)
        }
        return Hero(username: decoded.username,
                    status: "last seen \(relativeTime(epoch: decoded.last_online))",
                    url: decoded.url.isEmpty ? fallbackURL : decoded.url)
    }

    // lichess exposes online/playing (no last-seen time) for a batch of users.
    private struct LichessStatus: Decodable {
        let id: String
        let name: String
        let online: Bool?
        let playing: Bool?
    }

    static func lichessHeroes(_ usernames: [String]) async -> [Hero] {
        guard !usernames.isEmpty else { return [] }
        let ids = usernames.joined(separator: ",")
        guard let url = URL(string: "https://lichess.org/api/users/status?ids=\(ids)"),
              let data = try? await get(url),
              let decoded = try? JSONDecoder().decode([LichessStatus].self, from: data)
        else {
            return usernames.map { Hero(username: $0, status: nil, url: nil) }
        }
        var byId: [String: LichessStatus] = [:]
        for entry in decoded { byId[entry.id.lowercased()] = entry }
        return usernames.map { username in
            guard let entry = byId[username.lowercased()] else {
                return Hero(username: username, status: nil, url: nil)
            }
            let status = entry.playing == true ? "playing now" : (entry.online == true ? "online" : "offline")
            return Hero(username: entry.name, status: status, url: "https://lichess.org/@/\(entry.name)")
        }
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
