# Handoff — the watch-engine pivot

_Last updated: 2026-06-15. Branch: **`watch-engine`** — `main` is untouched. All work below is
committed and pushed to `origin/watch-engine`._

## Where we are

knight is being turned from a chess-only menu-bar app into a general, **local-first** watcher
with chess as the default skin. Full design + rationale in `DESIGN.md`. Three slices are done:

| Commit | Slice | What it does |
| --- | --- | --- |
| `2fdedb4` | 1a | Chess becomes a `Connector`; generic `Engine` + `RuleEvaluator` (appears + threshold rules); keystone `Watcher` type; no-op reasoning-hook seam. **No behavior change.** |
| `6a5c80b` | 1b | `GenericJSONConnector` runs `Config.watchers` — fetch a URL, extract a value by dot-path, notify on a rule. Renders in the panel + `--check`. |
| `cffae7a` | 1c | The "+ Add a watch…" visual picker — paste a JSON URL, click a numeric value, pick a plain-language rule, name it, Add. Writes a `Watcher` and refreshes. |

## Verified

- Clean builds (debug + signed release bundle) at every step.
- 1a: chess, the panel, and `--check` are byte-identical; legacy notification keys preserved
  (existing installs won't re-seed).
- 1b: generic watches resolved end-to-end against a live API (top-level + nested dot-paths).
- 1c: the bundled app launches and stays alive with all the new wiring.
- **Local-first kept:** the only network calls are to the URLs the user (or the picker) adds.
  No backend, no telemetry; all state in `~/.jugada` + `UserDefaults`.

## Not yet verified — do this first when resuming

The **interactive picker window** (click "+ Add a watch…" → fetch → click a value → Add) needs
a human click on the menu-bar icon; menu-bar UI automation wasn't reliable to script. 30-sec test:
1. `open /Applications/Knight.app`, click the knight icon → **+ Add a watch…**
2. Paste `https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd` → **Fetch**
3. Click `bitcoin › usd` → "goes below" → name it → **Add** → it appears in the panel.

## Installed app

`/Applications/Knight.app` is a fresh `watch-engine` build (1a+1b+1c). Version label still reads
**0.1.8** — not bumped (that's a release step). `~/.jugada` config is untouched.

## Adding a watch by hand (until recipes ship)

Add a `watchers` array to `~/.jugada/config.json`; see the example in `DESIGN.md`
("Configuring a watch by hand"). Numeric values only for now; rules `above`/`below`/`equals`
(need `value`) or `changes`.

## Next steps (recommended order)

1. **Run the picker test** above to close the one verification gap.
2. **Rewrite the README** — it still says "a tiny chess companion"; the product is now
   "watch anything from your menu bar — chess built in." Do before any release.
3. **Merge `watch-engine` → `main` and cut a version** (this is a real feature — likely v0.2.0).
4. Later slices: a **delete-a-watch** row in the panel; the **recipe gallery** (deferred from
   1c); **knight+** reasoning (the post-poll hook seam is in `Engine.swift`, ready, on-device
   by design — see `DESIGN.md`).

## New / changed files (reference)

New: `Watcher.swift`, `WatchSection.swift`, `Connector.swift`, `ChessConnector.swift`,
`Engine.swift`, `RuleEvaluator.swift`, `GenericJSONConnector.swift`, `JSONFlatten.swift`,
`AddWatch.swift`, plus `DESIGN.md` / this file.
Changed: `AppDelegate.swift`, `Notifier.swift`, `Config.swift`, `Panel.swift`, `main.swift`.
