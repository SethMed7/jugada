import SwiftUI

/// State the popover renders. AppDelegate owns it and refreshes `snapshot`;
/// the closures route row taps back to AppKit (open URL / refresh / quit).
final class PanelModel: ObservableObject {
    @Published var snapshot: Snapshot?
    @Published var source: String = "lichess"   // drives the source toggle (whole app)
    var onOpen: (String) -> Void = { _ in }
    var onRefresh: () -> Void = {}
    var onQuit: () -> Void = {}
    var onSetSource: (String) -> Void = { _ in }
}

// jugada brand: brass gold on deep board-green.
private extension Color {
    static let jBg = Color(red: 0x12 / 255, green: 0x27 / 255, blue: 0x1C / 255)
    static let jGold = Color(red: 0xDD / 255, green: 0xA9 / 255, blue: 0x4A / 255)
    static let jCream = Color(red: 0xEC / 255, green: 0xE3 / 255, blue: 0xCF / 255)
    static let jSage = Color(red: 0x8F / 255, green: 0xA2 / 255, blue: 0x93 / 255)
    static let jBorder = Color(red: 0x2C / 255, green: 0x56 / 255, blue: 0x40 / 255)
}

/// The themed dropdown — a board-green panel with gold hover rows.
struct PanelView: View {
    @ObservedObject var model: PanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Text("\u{265E}").font(.system(size: 17)).foregroundColor(.jGold)
                Text("knight").font(.system(size: 18, weight: .semibold, design: .serif)).foregroundColor(.jCream)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            Rectangle().fill(Color.jBorder).frame(height: 1)

            VStack(alignment: .leading, spacing: 1) {
                puzzleRow
                divider
                Header(isLichess ? "Live events" : "Live streamers")
                eventsRows
                divider
                Header("Heroes")
                heroesRows
                divider
                Row(title: isLichess ? "Watch Lichess TV" : "Watch chess.com TV") {
                    model.onOpen(isLichess ? "https://lichess.org/tv" : "https://www.chess.com/tv")
                }
                divider
                settingsRow
                divider
                Row(title: "Refresh") { model.onRefresh() }
                Row(title: "Quit knight") { model.onQuit() }
            }
            .padding(8)
        }
        .frame(width: 360)
        .background(Color.jBg)
    }

    private var divider: some View {
        Rectangle().fill(Color.jBorder.opacity(0.55)).frame(height: 1).padding(.horizontal, 4).padding(.vertical, 4)
    }

    private var isLichess: Bool {
        let s = model.source.lowercased()
        return s != "chess.com" && s != "chesscom"
    }

    private var settingsRow: some View {
        HStack(spacing: 7) {
            Text("Source").font(.system(size: 12.5)).foregroundColor(.jSage)
            Spacer(minLength: 8)
            SourceChip(label: "lichess", selected: isLichess) { model.onSetSource("lichess") }
            SourceChip(label: "chess.com", selected: !isLichess) { model.onSetSource("chess.com") }
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
    }

    @ViewBuilder private var puzzleRow: some View {
        switch model.snapshot?.puzzle {
        case .success(let p): Row(title: p.title, detail: p.detail, featured: true) { model.onOpen(p.url) }
        case .failure: Row(title: "Daily puzzle", detail: "— offline", enabled: false) {}
        case .none: Row(title: "Daily puzzle", detail: "Loading…", enabled: false) {}
        }
    }

    @ViewBuilder private var eventsRows: some View {
        switch model.snapshot?.broadcasts {
        case .success(let tours) where !tours.isEmpty:
            ForEach(Array(tours.enumerated()), id: \.offset) { _, tour in
                Row(title: tour.name, dot: true) { model.onOpen(tour.url) }
            }
        case .success: Row(title: isLichess ? "No live events" : "No live streamers", enabled: false) {}
        case .failure: Row(title: "— offline", enabled: false) {}
        case .none: Row(title: "Loading…", enabled: false) {}
        }
    }

    @ViewBuilder private var heroesRows: some View {
        switch model.snapshot?.heroes {
        case .success(let heroes):
            ForEach(Array(heroes.enumerated()), id: \.offset) { _, hero in
                if let status = hero.status, let url = hero.url {
                    Row(title: hero.username, detail: "· \(status)") { model.onOpen(url) }
                } else {
                    Row(title: hero.username, detail: "· offline", enabled: false) {}
                }
            }
        case .failure: Row(title: "— offline", enabled: false) {}
        case .none: Row(title: "Loading…", enabled: false) {}
        }
    }
}

private struct Header: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold)).tracking(0.9)
            .foregroundColor(.jSage)
            .padding(.horizontal, 10).padding(.top, 7).padding(.bottom, 2)
    }
}

private struct Row: View {
    let title: String
    var detail: String? = nil
    var dot: Bool = false
    var featured: Bool = false
    var enabled: Bool = true
    let action: () -> Void
    @State private var hover = false
    private var active: Bool { featured || (hover && enabled) }

    var body: some View {
        HStack(spacing: 8) {
            if dot { Circle().fill(active ? Color.jBg : Color.jGold).frame(width: 6, height: 6) }
            Text(title)
                .font(.system(size: 13.5))
                .foregroundColor(enabled ? (active ? .jBg : .jCream) : .jSage)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(active ? Color.jBg.opacity(0.72) : .jSage)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(active ? Color.jGold : Color.clear))
        .contentShape(Rectangle())
        .onHover { if enabled { hover = $0 } }
        .onTapGesture { if enabled { action() } }
    }
}

/// A pill in the puzzle-source toggle; the selected source is filled gold.
private struct SourceChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .foregroundColor(selected ? .jBg : (hover ? .jCream : .jSage))
            .padding(.horizontal, 11).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.jGold : (hover ? Color.jBorder.opacity(0.45) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? Color.clear : Color.jBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .onTapGesture { action() }
    }
}
