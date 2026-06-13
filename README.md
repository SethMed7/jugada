<div align="center">

![jugada — your chess world, one menu away.](assets/banner.png)

**jugada** — Spanish for *"the move"* (a play in chess). A tiny chess companion that
lives in your macOS menu bar: the daily puzzle, live broadcasts, and your chess heroes —
one click away, all day.

[![Release](https://img.shields.io/github/v/release/SethMed7/jugada?color=5681b5&label=release)](https://github.com/SethMed7/jugada/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-7fb0dc)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-13%2B-161616)](#install)
[![Data](https://img.shields.io/badge/data-lichess.org%20%C2%B7%20chess.com-5681b5)](#features)

</div>

Jugada puts a crown ♔ in your menu bar. Click it and your chess world unfolds: today's
lichess puzzle with its rating and themes, the official broadcasts happening right now,
and when your favorite players were last online. Everything opens in your browser; the
menu refreshes itself every five minutes. Sibling of
[narrado](https://github.com/SethMed7/narrado) and
[leelo](https://github.com/SethMed7/leelo) — same family, different board.

## How it works

![the jugada menu — daily puzzle, live events, heroes, lichess tv](assets/menu.png)

## Features

- **Daily puzzle** — rating + themes at a glance; one click opens
  [lichess training](https://lichess.org/training/daily)
- **Live events** — up to five official lichess broadcasts (Tata Steel, Norway Chess…),
  each a click from the live board
- **Heroes** — your favorite chess.com players and when they were last seen online;
  pick them in `~/.jugada/config.json`
- **Watch Lichess TV** — the best game on lichess, instantly
- **Self-refreshing** — every 5 minutes, plus a manual **Refresh**; sections degrade
  gracefully when offline
- **Private by design** — no accounts, no keys, no tracking; talks only to
  `lichess.org` and `api.chess.com`

## Install

1. Download `Jugada-x.y.z.zip` from [Releases](https://github.com/SethMed7/jugada/releases/latest),
   unzip, drag **Jugada.app** to Applications, and open it.
   The app is ad-hoc signed; if macOS complains, run:
   `xattr -d com.apple.quarantine /Applications/Jugada.app` (or right-click → Open).
2. That's it. **Permissions: none.** No accounts, no keys; jugada talks only to
   `lichess.org` and `api.chess.com`.

To follow your own heroes, edit `~/.jugada/config.json` (created on first run):

```json
{ "heroes": ["magnuscarlsen", "hikaru"] }
```

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
<sub>♞ <b>jugada</b> · your chess world, one menu away · part of the family:
<a href="https://github.com/SethMed7/narrado">narrado</a> ·
<a href="https://github.com/SethMed7/leelo">leelo</a> ·
<a href="https://github.com/SethMed7/dictado">dictado</a> ·
<b>jugada</b></sub>
</div>
