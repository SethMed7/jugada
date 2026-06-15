# knight — from chess app to general watcher

> Design doc for the pivot: keep knight a chess companion on the surface, but make
> chess **one connector** on top of a small, deterministic, **local-first** watch engine.
> Status: proposed. Nothing here is built yet.

## The reframe

knight is already a watcher; chess is the only plugin it has. The current code is a
domain-agnostic loop wearing chess vocabulary:

| What it does today | The generic primitive underneath |
| --- | --- |
| `Feeds.snapshot()` polls puzzle / live / heroes concurrently, each a `Result` that degrades instead of crashing | **poll a set of sources, fail soft per-section** |
| `Timer(300s, .common)` in `AppDelegate` | **the cron loop that runs while the system is awake** |
| `Notifier.handle()` diffs broadcasts vs a seen-set and banners anything new | **change detection → notification** |
| `Snapshot { puzzle, broadcasts, heroes }` | **sections of items** |
| `Source` enum + panel toggle | **provider selection** |
| `~/.jugada/config.json` | **local subscription storage** |

So this is a **promotion, not a rewrite**: lift `Source` from a chess enum to a `Connector`
protocol, and lift `Notifier`'s broadcast-diff into a generic rule evaluator. Chess stays
pixel-identical as the flagship connector and the default skin.

**Positioning:** general watcher, chess as the default skin. Tagline shifts from
*"chess in your menu bar"* to *"watch anything from your menu bar — chess built in."*
A knight stands watch; the name and icon stay.

---

## Principle #1 — local-first and private (load-bearing)

knight's README already promises *"no accounts, no keys, no tracking."* Generalizing must
not break that promise. The rules below are non-negotiable and constrain every later choice.

- **No knight backend. No account. No telemetry. No phone-home.** There is no first-party
  server anywhere in this design.
- **knight connects only to the data sources the user explicitly adds** — directly, source
  by source. A watcher *must* reach the thing it watches; that is its function, not a leak.
  Nothing *about the user* is ever transmitted.
- **Every source URL is visible to the user.** A recipe shows the endpoint it uses; a custom
  watch is a URL the user pasted. No hidden calls.
- **All state stays local** — `~/.jugada/config.json` and `UserDefaults`, where it already
  lives. Watchers, rules, and seen-sets never leave the machine.
- **No identifying request data.** Requests carry only a generic `User-Agent`. No cookies, no
  auth, unless the user supplies a header themselves (for an API key they own).
- **Reasoning (knight+) is on-device by default** — a local model over `localhost`
  (e.g. Ollama), never a cloud API in the core. A cloud LLM is an explicit, clearly
  disclosed, **off-by-default** opt-in.
- **The local push bus binds `127.0.0.1` only.** No internet tunnel ships in the core; that
  would contradict this posture. If a user wants inbound webhooks from the internet they set
  up their own tunnel, deliberately and at their own risk — knight does not do it for them.

If a feature can't be built within these rules, it doesn't ship in the core.

---

## Core concepts

### The Watcher — one representation, three creators

Everything the user adds compiles down to a single `Codable` struct. This is what config
stores, what the engine runs, and what every "add a watch" flow produces:

```
Watcher {
  name, icon
  source:  { url, headers?, interval }      // where to poll (user-visible)
  extract: { path }                          // which value out of the JSON (dot-path)
  rule:    { type: appears | above | below | changes | equals, value? }
  display: { title, detail?, link? }         // what the row / banner says
}
```

The key idea that makes a "paste-a-JSON-URL" connector usable by non-technical people:
**the generic JSON connector is the runtime; it is never the UI.** Nobody types a path.
Three *creators* all emit the same `Watcher`, graded by how technical the user is:

1. **Recipes** (non-tech default) — a pre-baked `Watcher` with the URL + path filled in and
   only the human variable left blank ("which coin?", "which ticker?"). Reads like plain
   English; the user never sees the endpoint or the path. Recipes are shareable blobs → the
   non-tech onramp *and* a growth loop.
2. **Visual picker** ("click, don't type") — for a custom source: paste a URL, knight fetches
   it and shows the JSON flattened to clickable leaf values with human labels; the user
   **clicks the value** and knight infers the path. The rule is dropdowns
   (goes above / below / changes), pre-filled with the live reading.
3. **Natural language** (knight+, built later) — "tell me when bitcoin drops under 60k"
   emits the *same* `Watcher`. This is just creator #3; see seams below.

### Item, Section

A `Section` is `{ title, items, notifyMode }`. An `Item` is what a `Row` renders today
(`title, detail?, url?, status?, dot?`) plus the two fields that make it watchable:

- **identity** — for "is this new?" diffing (today this is `event.url`).
- **value** — a number/string for threshold rules.
- **raw snippet** (small) — kept so a future on-device summarizer has material; unused by the
  core.

### Connector

```
protocol Connector {
  var id: String { get }
  var displayName: String { get }
  func poll() async -> [Section]
}
```

Built-ins:

- **`ChessConnector`** — wraps today's `Feeds` logic, emits the puzzle / live / heroes
  sections. Behavior identical to current knight. This is the default skin.
- **`GenericJSONConnector`** — runs the user's `[Watcher]`: fetch each `source.url`, extract
  `path`, evaluate `rule`, emit sections.

The engine holds an ordered list of connectors, polls them on the existing timer, assembles
the snapshot, runs the (no-op for now) reasoning hook, then hands notify-eligible items to
`Notifier`. The headless `--check` mode must keep working against this engine.

### Watch types (the deterministic core — zero reasoning)

1. **Appearance** — "notify when a new item shows up." This *is* today's `Notifier.handle()`
   diff, unchanged, generalized to any section flagged notify-on-new.
2. **Threshold** — "notify when a value crosses a line" (`above` / `below` / `changes` /
   `equals`). **Edge-detected**: fire on the *crossing*, not on every poll while the condition
   holds. Needs a tiny per-watcher last-value store alongside the seen-set.

That's the whole free product: pick sources, pick rules, get notified. No model, no cost,
fully private.

---

## The non-tech "Add a watch" flow

```
+ Add a watch
┌─────────────────────────────────────────┐
│  📈 Stock price     🪙 Crypto price       │   ← recipe gallery
│  🔴 Twitch live     ▶️  YouTube count     │
│  🌦  Weather        📰 RSS feed           │
│  ⚽ Sports team     🛠  Custom…           │
└─────────────────────────────────────────┘

  🪙 Crypto price                              ← recipe: only the human variable is asked
  Which coin?            [ Bitcoin ▾ ]
  Notify me when it      [ goes below ▾ ]  [ $60,000 ]
                                      ( Add )

  🛠 Custom…                                   ← visual picker: click, don't type
  Paste a data link:  [ https://api.…/quote ]   ( Fetch )
  We found these — click the one to watch:
    • symbol .......... "AAPL"
    • price ........... 201.34   ← click → path inferred
    • change% ......... +1.2
  Notify me when  price  [ goes above ▾ ]  [ 201.34 ]   ← pre-filled with live value
  Banner says:    "{symbol} is {price}"  (default)        ( Add )
```

---

## knight+ reasoning — seams to build now, model to add later

"Design the seams, build later." The seams are cheap because the friendliness solution and
the Plus tier are the *same* seam: the `Watcher` struct.

1. **`Watcher` is the universal target** — `NL → Watcher` is a pure function whose output type
   already exists. Define the struct well now and natural-language watches drop in later
   without touching the engine.
2. **Items carry raw value + snippet** — so a future digest / summarizer has material.
3. **Post-poll hook** — after the engine has items but before `Notifier` fires, leave a
   pass-through where a reasoning step *could* filter / summarize / soft-match. Ship the
   identity function now.
4. **Notification payload carries `{ watcherId, value }`** (today it carries `url`) — so a
   future "why did this fire? / explain" action works.

**Reasoning stays local-first.** The hook runs on-device; the realistic default is a local
model over `localhost` (Ollama / MLX). Apple's on-device Foundation Models are an option only
if/when the deployment target rises above the current macOS 13. A cloud LLM is an explicit
opt-in, disclosed, off by default — never assumed by the architecture.

**knight+ flagship candidate:** *watch any web page* — extracting a value from arbitrary HTML
is exactly the fuzzy job a model is good at and a predicate is not. It keeps the free core
deterministic and gives Plus a genuinely hard-to-copy hook.

---

## The local push bus (optional, off by default)

The existing timer already covers polling, so a server isn't needed for that. The new
capability a local listener buys is **inbound** — turning knight into a personal notification
bus: a shell script, a Shortcut, or another local tool can raise a knight banner via
`curl 127.0.0.1:<port>/notify`. Bound to loopback only; opt-in; no tunnel. This is a later
slice, not part of the first proof.

---

## Boundaries (named on purpose)

- **JSON APIs only, phase 1.** Recipes and the visual picker cover JSON endpoints. Recipes
  hide that a source is an API behind a friendly name.
- **Web pages are out of core.** Scraping a value from arbitrary HTML is a knight+ feature
  (see above), not a deterministic one.
- **Auth'd sources are user-supplied.** If a source needs a key, the user pastes it as a
  header; knight ships no keys and stores the header locally like any other config.

---

## Recommended first slice

A vertical slice that proves the thesis without endangering chess. Staged so each step is
shippable on its own:

**Slice 1a — engine + Watcher struct + chess as a connector (no behavior change).**
- Add `Connector` protocol, `Watcher`/`Item`/`Section` structs, and an `Engine` that polls a
  list of connectors.
- Re-express today's `Feeds` logic as `ChessConnector`; the panel and `--check` behave
  identically.
- Generalize `Notifier` to the `appears` rule; add `above`/`below`/`changes`/`equals` with
  edge detection + a per-watcher last-value store.

**Slice 1b — generic JSON connector, config-driven.**
- `GenericJSONConnector` reads `watchers: [Watcher]` from `~/.jugada/config.json`, polls,
  extracts, evaluates, emits sections that render in the panel and notify.
- At this stage watchers can be added by hand-editing config — proves the engine end to end.

**Slice 1c — the friendly "Add a watch" UI (the actual proof for non-tech users).**
- Recipe gallery (start with Crypto via CoinGecko = no auth, RSS = universal, one stock).
- The visual click-to-pick custom flow.
- Both write `Watcher`s into config; no path typing anywhere.

**Seams (in 1a):** the post-poll reasoning hook (no-op) and the `Watcher`-as-NL-target. No
model code yet.

---

## Configuring a watch by hand (Slice 1b — shipped)

Until the friendly "Add a watch" UI lands (1c), generic watches are added to
`~/.jugada/config.json` as a `watchers` array. Each entry is one `Watcher`. Example —
notify when Bitcoin drops below $60k:

```json
{
  "heroes": ["magnuscarlsen", "hikaru"],
  "source": "chess.com",
  "watchers": [
    {
      "name": "Bitcoin",
      "source": { "url": "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd" },
      "extract": { "path": "bitcoin.usd" },
      "rule": { "type": "below", "value": 60000 },
      "display": { "title": "Bitcoin", "detail": "{value} USD" }
    }
  ]
}
```

- `extract.path` is a dot-path into the JSON: object keys and array indices both work
  (e.g. `rows.0.score`).
- `rule.type` is `above` / `below` / `equals` (each needs `value`) or `changes` (no value).
  Rules are edge-triggered and silently seeded on first poll — no banner storm at launch.
- **Numeric values only** in 1b (price / count / rating); string and array (`appears`)
  sources come later. A failed or non-numeric fetch shows an offline row and never notifies.
- `display.detail` may contain `{value}`, replaced with the current reading. `display.link`
  is optional (the row opens it on click).

Watches show in the panel below the chess skin and in `Jugada --check`. They run through
the same engine as chess, so they're equally local-first: knight calls only the URL you put
in `source.url`.

## What changes vs. what stays

- **Stays:** the timer loop, fail-soft per-section snapshots, the themed panel + `Row`,
  open-in-browser behavior, the seen-set diff logic, `~/.jugada/config.json`, `--check`,
  and — above all — **"private by design."**
- **Changes:** `Source` enum → `Connector` protocol; `Snapshot`'s fixed fields → a list of
  `Section`s from a list of connectors; `Notifier` broadcast-specific diff → generic rule
  evaluator; `Config` grows a `watchers` array (keeps `heroes` + `source` for the chess skin).
