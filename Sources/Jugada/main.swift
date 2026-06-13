import AppKit

// Consumed contract — provided by Feeds.swift / Snapshot.swift (built separately):
//   Feeds.snapshot() async -> Snapshot
//   Snapshot { puzzle: Result<Puzzle, Error>
//              broadcasts: Result<[Broadcast], Error>
//              heroes: Result<[Hero], Error> }
//   Puzzle    { rating: Int, themes: [String] }
//   Broadcast { name: String, url: String }
//   Hero      { username: String, lastSeen: String?, url: String? }   // lastSeen nil = that hero's fetch failed

func sectionFailed<T>(_ result: Result<T, Error>) -> Bool {
    if case .failure = result { return true }
    return false
}

func heroLine(_ hero: Hero) -> String {
    guard let lastSeen = hero.lastSeen else { return "\(hero.username) · — offline" }
    return "\(hero.username) · last seen \(lastSeen)"
}

func checkText(_ snapshot: Snapshot) -> String {
    var lines: [String] = []
    switch snapshot.puzzle {
    case .success(let p):
        lines.append("Daily puzzle · rating \(p.rating) · \(p.themes.joined(separator: ", "))")
    case .failure:
        lines.append("Daily puzzle · — offline")
    }
    switch snapshot.broadcasts {
    case .success(let tours):
        lines.append("Live events (\(tours.count)):")
        for tour in tours { lines.append("  \(tour.name)") }
    case .failure:
        lines.append("Live events · — offline")
    }
    switch snapshot.heroes {
    case .success(let heroes):
        lines.append("Heroes:")
        for hero in heroes { lines.append("  \(heroLine(hero))") }
    case .failure:
        lines.append("Heroes · — offline")
    }
    return lines.joined(separator: "\n")
}

if CommandLine.arguments.contains("--version") {
    print("0.1.0")
    exit(0)
}

// Headless check mode: `Jugada --check` fetches everything once, prints a
// plain-text snapshot, and exits non-zero only when ALL sections failed.
// Detached task so the semaphore wait below can never deadlock the main thread.
if CommandLine.arguments.contains("--check") {
    final class ExitBox: @unchecked Sendable { var code: Int32 = 0 }
    let box = ExitBox()
    let done = DispatchSemaphore(value: 0)
    Task.detached {
        let snapshot = await Feeds.snapshot()
        print(checkText(snapshot))
        let allFailed = sectionFailed(snapshot.puzzle)
            && sectionFailed(snapshot.broadcasts)
            && sectionFailed(snapshot.heroes)
        box.code = allFailed ? 1 : 0
        done.signal()
    }
    done.wait()
    exit(box.code)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
