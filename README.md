<div align="center">

![jugada — your chess world, one menu away.](assets/banner.png)

**A tiny chess companion for the macOS menu bar** — the daily puzzle, live broadcasts,
and your chess heroes, one click away, all day. No accounts, no keys, no tracking.

[![Release](https://img.shields.io/github/v/release/SethMed7/jugada?color=DDA94A&label=release)](https://github.com/SethMed7/jugada/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-DDA94A)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-13%2B-12271C)](#install)
[![Data](https://img.shields.io/badge/data-lichess.org%20%C2%B7%20chess.com-DDA94A)](#features)

</div>

**jugada** — Spanish for *"the move."* It puts a crown ♔ in your menu bar; click it and a
board-green panel unfolds: today's daily puzzle (from **lichess** or **chess.com**, your
choice), the official broadcasts playing right now — with a notification when a new one goes
live — when your favorite players were last online, and a one-click ticket to Lichess TV.
Everything opens in your browser. It refreshes itself every five minutes. No login, nothing
to configure to start. Part of a small family — sibling of
[narrado](https://github.com/SethMed7/narrado) and [leelo](https://github.com/SethMed7/leelo)
— same craft, a different board.

## How it works

![the jugada menu — daily puzzle, live events, heroes, lichess tv](assets/menu.png)

## Features

- **Daily puzzle** — from **lichess** (rating + themes) or **chess.com**, your choice in
  `~/.jugada/config.json`; one click opens it
- **Live events** — up to five official lichess broadcasts (Tata Steel, Norway Chess…),
  each one click from the live board
- **Live-event alerts** — a macOS notification the moment a new broadcast goes live; click
  the banner to jump straight to the board
- **Heroes** — your favorite chess.com players and when they were last seen; choose them
  in `~/.jugada/config.json`
- **Watch Lichess TV** — the best game on lichess, instantly
- **A themed panel** — board-green with brass-gold highlights, not a plain system menu
- **Self-refreshing** — every 5 minutes, plus a manual **Refresh**; each section degrades
  gracefully when you're offline
- **Private by design** — no accounts, no keys, no tracking; talks only to `lichess.org`
  and `api.chess.com`

## Install

1. Download `Jugada-x.y.z.zip` from [Releases](https://github.com/SethMed7/jugada/releases/latest),
   unzip, drag **Jugada.app** to Applications, and open it. The app is ad-hoc signed; if macOS
   complains, run `xattr -dr com.apple.quarantine /Applications/Jugada.app` (or right-click → Open).
2. That's it — **no permissions to grant.** jugada talks only to `lichess.org` and
   `api.chess.com`.

On first run, the first time a new broadcast goes live you'll get a **notification**; macOS
asks for permission once.

To follow your own heroes — or switch the puzzle source — edit `~/.jugada/config.json`
(created on first run):

```json
{
  "heroes": ["magnuscarlsen", "hikaru"],
  "puzzleSource": "lichess"
}
```

Set `"puzzleSource"` to `"chess.com"` to use chess.com's daily puzzle instead of lichess.

## Development

```sh
swift build              # debug build
sh scripts/bundle.sh     # release build -> build/Jugada.app (no Xcode project needed)
./build/Jugada.app/Contents/MacOS/Jugada --check   # headless snapshot of all sections
```

Brand assets are authored as HTML/SVG in `assets/` and rendered with
`bunx playwright screenshot`.

## License

MIT

<div align="center">
<sub>♞ <b>jugada</b> · brass on board-green · your chess world, one menu away · part of the
family: <a href="https://github.com/SethMed7/narrado">narrado</a> ·
<a href="https://github.com/SethMed7/leelo">leelo</a> ·
<a href="https://github.com/SethMed7/dictado">dictado</a></sub>
</div>
