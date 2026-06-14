import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var isRefreshing = false // main-thread only; guards overlapping refreshes
    private let popover = NSPopover()
    private let model = PanelModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "crown", accessibilityDescription: "Jugada")
                ?? NSImage(systemSymbolName: "circle.grid.3x3", accessibilityDescription: "Jugada")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Route the themed panel's taps back to AppKit.
        model.onOpen = { [weak self] urlString in
            self?.openLink(urlString)
            self?.popover.performClose(nil)
        }
        model.onRefresh = { [weak self] in self?.refresh() }
        model.onQuit = { NSApp.terminate(nil) }
        model.puzzleSource = Config.load().puzzleSource ?? "lichess"
        model.onSetPuzzleSource = { [weak self] source in
            Config.setPuzzleSource(source)
            self?.model.puzzleSource = source
            self?.refresh()
        }

        popover.behavior = .transient
        popover.animates = true
        let hosting = NSHostingController(rootView: PanelView(model: model))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        if let dark = NSAppearance(named: .vibrantDark) { popover.appearance = dark }

        UNUserNotificationCenter.current().delegate = self
        Notifier.requestAuth()

        // .common run-loop mode so the 5-minute refresh fires even while the
        // popover is open (and notifications still arrive while it's closed).
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        refresh()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            refresh() // freshen the panel each time it opens
        }
    }

    /// Open in the default web browser explicitly. Plain `NSWorkspace.open` lets
    /// an app that claims a domain's universal links (e.g. the chess.com app)
    /// hijack the link; we resolve the browser via a neutral domain and open
    /// there so every jugada link lands in the browser, as documented.
    private func openLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        if let probe = URL(string: "https://example.com"),
           let browser = NSWorkspace.shared.urlForApplication(toOpen: probe) {
            NSWorkspace.shared.open([url], withApplicationAt: browser,
                                    configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let snapshot = await Feeds.snapshot()
            await MainActor.run {
                self.model.snapshot = snapshot
                if case .success(let tours) = snapshot.broadcasts { Notifier.handle(tours) }
                self.isRefreshing = false
            }
        }
    }

    // MARK: notifications

    // Tapping a live-event banner opens its board.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let urlString = response.notification.request.content.userInfo["url"] as? String {
            openLink(urlString)
        }
        completionHandler()
    }

    // Show the banner even though jugada runs as a menu-bar accessory.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
