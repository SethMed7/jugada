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
            button.image = AppDelegate.knightImage()
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
        model.source = Config.load().effectiveSource
        model.onSetSource = { [weak self] value in
            Config.setSource(value)
            self?.model.source = value
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

    // The menu-bar icon is the knight itself (the same silhouette as the app
    // icon), drawn as a template so macOS tints it to the menu bar. Focus on
    // the horse — no generic crown symbol.
    private static func knightImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            let scale = NSAffineTransform()
            scale.scale(by: 18.0 / 256.0)
            scale.concat()
            let body = NSBezierPath()
            body.move(to: NSPoint(x: 100, y: 178))
            body.curve(to: NSPoint(x: 88, y: 116), controlPoint1: NSPoint(x: 100, y: 144), controlPoint2: NSPoint(x: 106, y: 124))
            body.line(to: NSPoint(x: 68, y: 122))
            body.curve(to: NSPoint(x: 58, y: 104), controlPoint1: NSPoint(x: 56, y: 124), controlPoint2: NSPoint(x: 50, y: 112))
            body.line(to: NSPoint(x: 94, y: 78))
            body.curve(to: NSPoint(x: 124, y: 50), controlPoint1: NSPoint(x: 98, y: 62), controlPoint2: NSPoint(x: 110, y: 52))
            body.line(to: NSPoint(x: 132, y: 36))
            body.line(to: NSPoint(x: 146, y: 52))
            body.curve(to: NSPoint(x: 188, y: 130), controlPoint1: NSPoint(x: 172, y: 62), controlPoint2: NSPoint(x: 188, y: 94))
            body.curve(to: NSPoint(x: 180, y: 178), controlPoint1: NSPoint(x: 188, y: 150), controlPoint2: NSPoint(x: 184, y: 164))
            body.close()
            body.lineWidth = 14
            body.lineJoinStyle = .round
            body.lineCapStyle = .round
            NSColor.black.setFill()
            NSColor.black.setStroke()
            body.fill()
            body.stroke()
            NSBezierPath(roundedRect: NSRect(x: 62, y: 198, width: 132, height: 18), xRadius: 9, yRadius: 9).fill()
            return true
        }
        image.isTemplate = true
        return image
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
                if case .success(let tours) = snapshot.broadcasts {
                    Notifier.handle(source: Source.from(self.model.source), tours)
                }
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
