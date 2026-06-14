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

- **One source, your pick** — flip the **Source** toggle near the bottom of the panel to run
  the whole app on **lichess** or **chess.com**; the puzzle, the live section, and your tracked
  players all switch together (never a mix)
- **Daily puzzle** — lichess (rating + themes) or chess.com (today's title); one click opens it
- **Live** — lichess broadcasts (Tata Steel, Norway Chess…), or who's **streaming live** on
  chess.com; each one click away
- **Live-event alerts** — a macOS notification the moment something new goes live; click the
  banner to jump straight to it
- **Heroes** — the players you track (set in `~/.jugada/config.json`): their **online status**
  on lichess, or **last-seen time** on chess.com
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

To follow your own players — or switch the source — edit `~/.jugada/config.json` (created on
first run):

```json
{
  "heroes": ["magnuscarlsen", "hikaru"],
  "source": "lichess"
}
```

Set `"source"` to `"chess.com"` to run the whole app on chess.com instead — or just use the
**Source** toggle near the bottom of the panel, which writes it for you. Heroes are looked up
on the active platform, so list each player's lichess / chess.com handle accordingly.

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
