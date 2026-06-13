import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var isRefreshing = false // main-thread only; guards overlapping refreshes

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "crown", accessibilityDescription: "Jugada")
                ?? NSImage(systemSymbolName: "circle.grid.3x3", accessibilityDescription: "Jugada")
        }
        statusItem.menu = buildMenu(snapshot: nil)

        // .common run-loop mode so the 5-minute refresh fires even while a menu is open.
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        refresh()
    }

    @objc func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let snapshot = await Feeds.snapshot()
            await MainActor.run {
                // Assign a fresh menu; never mutate the live one while it may be tracking.
                self.statusItem.menu = self.buildMenu(snapshot: snapshot)
                self.isRefreshing = false
            }
        }
    }

    // MARK: menu

    private func buildMenu(snapshot: Snapshot?) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        switch snapshot?.puzzle {
        case .success(let p):
            menu.addItem(link("Daily puzzle · rating \(p.rating) · \(p.themes.joined(separator: ", "))",
                              url: "https://lichess.org/training/daily"))
        case .failure:
            menu.addItem(header("Daily puzzle"))
            menu.addItem(offlineItem())
        case nil:
            menu.addItem(header("Daily puzzle"))
            menu.addItem(disabled("Loading…"))
        }

        menu.addItem(.separator())
        menu.addItem(header("Live events"))
        switch snapshot?.broadcasts {
        case .success(let tours) where !tours.isEmpty:
            for tour in tours.prefix(5) {
                menu.addItem(link(tour.name, url: tour.url))
            }
        case .success:
            menu.addItem(disabled("No live events"))
        case .failure:
            menu.addItem(offlineItem())
        case nil:
            menu.addItem(disabled("Loading…"))
        }

        menu.addItem(.separator())
        menu.addItem(header("Heroes"))
        switch snapshot?.heroes {
        case .success(let heroes):
            for hero in heroes {
                if let lastSeen = hero.lastSeen, let url = hero.url {
                    menu.addItem(link("\(hero.username) · last seen \(lastSeen)", url: url))
                } else {
                    menu.addItem(disabled("\(hero.username) · — offline"))
                }
            }
        case .failure:
            menu.addItem(offlineItem())
        case nil:
            menu.addItem(disabled("Loading…"))
        }

        menu.addItem(.separator())
        menu.addItem(link("Watch Lichess TV", url: "https://lichess.org/tv"))
        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem(title: "Quit Jugada",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func offlineItem() -> NSMenuItem {
        disabled("— offline")
    }

    private func link(_ title: String, url: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(open(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = url
        return item
    }

    @objc private func open(_ sender: NSMenuItem) {
        guard let string = sender.representedObject as? String,
              let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
