# Design

## Context

The iOS client is a SwiftUI app with a single `NavigationStack` screen. `ContentView` owns the shared role-pool text (`@AppStorage("moba_role_pool")`), the lane-weight JSON (`@AppStorage("moba_role_weights_v1")`), grouping history, and generation. `GroupingEngine` is a pure engine covered by `MobaRandomTests`. A one-time bundled weight preset (`default-role-weights-v2.json`, marker `moba_builtin_weight_preset_v2_applied`) is currently applied from `ContentView.onAppear`.

The reference BO3 page provides a complete global-BP board: a 12-step sequence, an 8-pick no-ban game 3, prior-pick locking, per-game bans, seats, best-of-three scoring, defensive local persistence, and 131 96x96 WebP portraits. See `proposal.md` for motivation and the two capability specs for the behavior contract.

Constraints:

- iOS 18 deployment target, Swift 6, XcodeGen (`project.yml`), existing test target.
- The app is fully offline and declares no network permission; no new runtime dependency.
- The shared role-pool format is the one produced by the existing editor: one category per line, a colon, and the existing separator set.
- Android and the grouping web page are unchanged in this change; the reference BO3 HTML receives the same game-2 ban rule as a separate follow-up.

## Goals / Non-Goals

**Goals:**

- Add the BO3 tab without changing the grouping screen's structure or existing user data.
- Keep all draft rules in a pure, testable engine, separate from SwiftUI and persistence.
- Reuse the existing role-pool and weight systems instead of creating a second character database.
- Keep the board usable on iPhone portrait, iPhone landscape, iPad portrait, and iPad landscape.
- Make the avatar set a generated, reproducible asset rather than hand-maintained files.

**Non-Goals:**

- Rewriting the grouping engine or its weighted algorithm.
- Adding the BO3 board to the Android or grouping-web clients in this change.
- Importing the HTML page's `localStorage` state.
- Building a tournament bracket, multi-series archive, or online sync.
- Redesigning the app's global visual system beyond the BO3 arena header.

## Decisions

### 1. Root tab shell with the grouping screen untouched

`MobaRandomApp` renders a new `RootTabView` instead of `ContentView` directly. The tab view owns two independent `NavigationStack`s:

```
RootTabView
  |
  +-- Tab "随机" (person.3.fill)
  |     +-- ContentView (existing)
  |
  +-- Tab "BO3" (flag.2.crossed.fill)
        +-- Bo3DraftView
```

`ContentView` keeps its own pool, weights, history, and weight-settings navigation. The selected tab is stored in `@AppStorage("moba_selected_tab")` so a relaunch returns to the mode the user was using.

Alternative considered: a segmented control inside a single `NavigationStack`. It saves the tab bar's vertical space, but it is not a real tab, complicates the existing navigation title, and makes the two modes feel like one page. The user explicitly asked for a tab, and iOS 18's iPad tab bar is compact.

### 2. Pure engine plus a main-actor store

The rule layer is a `Bo3DraftEngine` with no SwiftUI or `UserDefaults` imports. It owns constants, sequence resolution, availability, scoring, seat generation, and state sanitization. A `@MainActor @Observable` `Bo3SeriesStore` owns the mutable series and persistence.

```
Bo3DraftView
  +-- Bo3SeriesStore (series mutations + save/load)
  +-- Bo3DraftEngine (pure rules)
  +-- Bo3Pool        (parsed shared pool)
  +-- Bo3AvatarCatalog (images + aliases + fallback)
```

Data model:

```swift
enum Bo3Team: String, Codable { case a, b }
enum Bo3ActionType: String, Codable { case ban, pick }

struct Bo3Step: Equatable {
    let team: Bo3Team
    let type: Bo3ActionType
}

struct Bo3Action: Codable, Equatable {
    let team: Bo3Team
    let type: Bo3ActionType
    let hero: String
    let role: String
}

struct Bo3Game: Codable, Equatable {
    var started: Bool
    var actions: [Bo3Action]
    var winner: Bo3Team?
    var noBan: Bool
}

struct Bo3Seats: Codable, Equatable {
    var a: [Int]
    var b: [Int]
}

struct Bo3TeamNames: Codable, Equatable {
    var a: String
    var b: String
}

struct Bo3Series: Codable, Equatable {
    var version: Int
    var teamNames: Bo3TeamNames
    var noBanGame3: Bool
    var seats: Bo3Seats?
    var currentGame: Int       // 0 = no series
    var games: [Bo3Game]       // always three entries
}
```

`currentGame == 0` is the single source of truth for "no series". The store exposes mutations (`startGame`, `choose`, `setWinner`, `reopenWinner`, `undo`, `reset`) rather than a public mutable series, so every mutation goes through validation and one save path.

Alternative considered: `@State var series` plus `onChange` saves. It is shorter, but it spreads rule checks into the view and makes the sanitization and persistence tests harder to write.

### 3. Sequence and game-3 rule resolution

The engine defines the sequences as constants:

```
STEP_SEQUENCE (12, game 1 and a full-ban game 3):
01 A ban   02 B ban
03 A pick  04 B pick  05 B pick  06 A pick
07 A ban   08 B ban
09 B pick  10 A pick  11 A pick  12 B pick

GAME2_STEP_SEQUENCE (12, mirrored A/B):
01 B ban   02 A ban
03 B pick  04 A pick  05 A pick  06 B pick
07 B ban   08 A ban
09 A pick  10 B pick  11 B pick  12 A pick

GAME3_NO_BAN_SEQUENCE (8):
A pick, B pick, B pick, A pick, B pick, A pick, A pick, B pick
```

Game 2 mirrors every A/B assignment so the same team does not get the first ban and first pick in every game; step types and the overall draft shape are unchanged. `GAME3_NO_BAN_SEQUENCE` is defined independently but tested to equal the pick-only filter of `STEP_SEQUENCE`, and `GAME2_STEP_SEQUENCE` is tested to swap every team while preserving every step type.

The rule for a game mirrors the reference behavior:

```swift
func noBan(for gameNo: Int, series: Bo3Series) -> Bool {
    guard gameNo == 3 else { return false }
    let game = series.games[2]
    return game.started ? game.noBan : series.noBanGame3
}
```

This means changing the setting after game 3 has started cannot rewrite the active game's sequence. The next series picks up the new setting.

### 4. Availability is current-game plus prior picks

```swift
enum Bo3Availability: Equatable {
    case available
    case currentGame(Bo3Action)
    case globalPick(game: Int, action: Bo3Action)
}
```

Resolution order:

1. Any action in the active game (ban or pick) locks the character for the rest of that game.
2. Any `pick` in a prior started game locks the character for the rest of the series.
3. Prior `ban` actions do not lock.
4. A prior pick keeps locking by character name even if the character is removed from and later re-added to the pool.

The current-game case wins for messaging so the user sees "already banned in this game" rather than a stale series lock. The grid precomputes a `[String: Bo3Availability]` map once per body; 131 cards and a handful of actions do not need incremental indexing.

Alternative considered: locking all prior actions, including bans. The reference explicitly resets bans each game, and doing otherwise would make ban-heavy teams consume the pool twice as fast. This is rejected.

### 5. Series persistence and defensive recovery

Use one new key, `moba_bo3_series_v1`, containing versioned JSON. The shared pool is deliberately not inside the payload; it stays in `moba_role_pool`.

Load order:

```
decode -> version check -> normalize names/settings -> clamp currentGame
  -> per game: choose sequence, copy valid action prefix, force team/type,
     trim hero/role, discard incomplete winner
  -> mark current game started -> reset future games
  -> validate or regenerate seats
```

The prefix rule stops at the first action that is empty, has an unknown team/type, or duplicates a character already present in that game. Later actions are not trusted even if they look valid, because skipping a bad action would silently change the draft order.

We do not port the reference page's legacy "ascending seats" reshuffle: there is no native predecessor save format, so that branch would be dead code. We do keep the "invalid seats in a started series -> regenerate" repair, because a corrupted seat payload should not block a draft.

The store saves after every mutation and on scene background. Saving twice is harmless; losing a pick because the app was suspended is not.

### 6. Shared pool parsing

`Bo3Pool` is built from `GroupingEngine.parseRolePool` plus a deduplication pass:

```swift
struct Bo3Pool {
    struct Category { let name: String; let heroes: [String] }
    let categories: [Category]
    let heroRole: [String: String]
    let duplicates: [String]
    var total: Int { heroRole.count }
}
```

- Categories and order come from the existing parser, so both tabs see the same names.
- The first occurrence of a character wins; later occurrences are recorded as duplicates and skipped.
- Empty categories after deduplication are not shown as filter chips.
- The parser still requires the app's `分类：角色` format. The reference page's looser comment/no-colon handling is not ported; the shared pool editor already owns that format, and having two parsers disagree would be worse than dropping unsupported syntax.

This wrapper is the only place BO3-specific pool semantics live. The grouping tab continues to use its existing parser unchanged.

### 7. Default roster and preset payload

The static default and the bundled preset both move to the reference roster:

```
射手 (7): 温迪、甘雨、宵宫、提纳里、公子、夜兰、赛索斯
打野 (6): 绫华、胡桃、雷神、刻晴、牢大、魈
中路 (8): 希格雯、钟离、八重、龙王、少女、纳西妲、可莉、琴
战士 (13): 菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、洛恩、迪卢克、杜林、法尔加、克洛林德、赛诺
```

Changes:

- `GroupingEngine.defaultPoolText` becomes the text above.
- `default-role-weights-v2.json` becomes a 34-character payload:
  - Add 杜林、法尔加、克洛林德、赛诺 with weight 100 in 战士.
  - Move 魈 to 打野 with `{打野: 100}` and `sourceLane = 打野`.
  - Move 琴 to 中路 with `{中路: 100}` and `sourceLane = 中路`.
  - Keep the other 29 character vectors unchanged.
- The existing marker `moba_builtin_weight_preset_v2_applied` and resource name `default-role-weights-v2` are retained.

Why keep the marker instead of shipping a new v3 marker: a new marker would be pending on every upgraded installation, and applying the new payload would overwrite users' current pools and weights. Keeping the marker means the preset is applied at most once per installation. Fresh installs get 34; an installation that already applied the 30-character preset keeps its data. This is a deliberate supersession of the earlier change's 30-character payload, not a second migration.

The preset's derived pool text must exactly equal `GroupingEngine.defaultPoolText`; the preset test should assert that, so the two defaults cannot drift.

Alternative considered: leave the preset at 30 and only change the static default. Rejected because fresh installs would still get 30 from the preset, defeating the chosen default.

### 8. Startup bootstrap for the preset

The preset migration currently lives in `ContentView.onAppear`. With a tab shell, a restored BO3 tab may be shown without `ContentView` ever appearing, so the pool could remain uninitialized. Extract the migration into an app-level bootstrap:

```swift
enum AppBootstrap {
    static func applyBuiltInWeightPresetIfNeeded(defaults: UserDefaults = .standard)
}
```

Call it from `MobaRandomApp.init` (synchronous, before either tab body). Behavior:

1. If `moba_role_pool` is empty, write `GroupingEngine.defaultPoolText`.
2. If the marker is present, stop.
3. If the marker is absent and the stored pool is empty or equals a known built-in default (the current default or a previously shipped roster), load and validate the bundled preset. On success, write the weights and derived pool, then mark. On failure, leave the marker pending and keep the default/stored pool.
4. If the marker is absent and the stored pool is custom, keep the pool and weights, mark the migration as handled, and do not apply the preset. This preserves pre-marker upgrades that already have a customized configuration.

Known built-in defaults are compared after normalizing line endings and per-line whitespace. The list includes the current 34-character roster plus the rosters shipped by earlier iOS builds and the reference page; an arbitrary custom pool is never replaced.

Remove the `ContentView.onAppear` call to avoid two code paths. The grouping view still loads history and generates on appear.

Alternative considered: keep the migration in `ContentView` and force the grouping tab to appear first. That breaks tab restoration and makes the BO3 tab depend on a view the user may never open.

### 9. Avatar asset pipeline

The reference HTML embeds 131 portraits as base64 WebP. Generate committed native resources instead of parsing the HTML at runtime:

```
scripts/extract_bo3_avatars.py <reference.html>
  -> MobaRandom/Resources/BO3/avatars/a001.webp ... a131.webp
  -> MobaRandom/Resources/BO3/avatar-index.json
```

Index shape:

```json
{
  "version": 1,
  "aliases": { "公子": "达达利亚", "绫华": "神里绫华", "...": "..." },
  "avatars": {
    "温迪": { "file": "a001", "element": "风" },
    "甘雨": { "file": "a002", "element": "冰" }
  }
}
```

- File names are ASCII ids, avoiding CJK path issues and resource-name normalization.
- The index maps official name to file and element; aliases map short names to official names.
- The generated assets and index are committed. The 567 KB reference HTML stays outside the repository; the script accepts its path and documents the provenance. The app bundle grows by roughly 335 KB before compression.
- XcodeGen gets a folder reference for `MobaRandom/Resources/BO3` with `buildPhase: resources`, excluded from the parent `MobaRandom` source entry to avoid duplicate copies.
- `Bo3AvatarCatalog` loads the index once, resolves alias -> official -> file, and loads images lazily through `NSCache<NSString, UIImage>`. `UIImage(contentsOfFile:)` uses ImageIO, which decodes WebP on the deployment target. A nil image falls back to the generated tile.
- Fallback: stable hash of the display name into two HSL stops, first character centered, same idea as the reference page.
- Element colors: 风 `#7AD7B5`, 火 `#FF8B6B`, 水 `#59B9FF`, 冰 `#A9E8FF`, 雷 `#C6A3FF`, 岩 `#F0C96F`, 草 `#93DC72`.
- Role colors: 射手 gold, 打野 green, 中路 violet, 战士 rose, 辅助 blue, 坦克 amber; unknown roles use a stable extra palette.
- `点刀` has no portrait in the reference set and intentionally renders the fallback. An alias can be added later without changing the asset format.

Alternative considered: embed the base64 JSON and decode at runtime. It is one file, but it carries a 455 KB JSON string, duplicates the image bytes, and makes Xcode resource handling and caching worse. Generated files are simpler to inspect and test.

### 10. Board composition and responsive layout

The board is one set of components arranged with measured width thresholds rather than a `GeometryReader` container:

```
Compact (iPhone portrait)
  VStack(spacing: 0)
    Bo3ArenaHeader          fixed, compact score + game badge overlay
      Bo3Timeline           embedded one-row strip
    Bo3LineupStrip          fixed, horizontally scrollable if needed
    pool filter/search bar  fixed
    ScrollView { Bo3HeroGrid }

Wide (iPhone landscape / iPad portrait)
  HStack
    VStack { compact arena with embedded timeline, lineup, pool header }
    ScrollView { Bo3HeroGrid }

Regular landscape (iPad)
  HStack
    Bo3TeamPanel(.a)        full bans, picks, prior games
    VStack { arena, timeline, pool header, grid }
    Bo3TeamPanel(.b)
```

`onGeometryChange` records the available size without wrapping the board in a `GeometryReader`; regular-width devices at 900 pt or wider use the three-column board, regular-width or compact-height devices use two columns, and the rest use the compact board. A height below 620 pt falls back to the fully scrolling accessibility board. Measuring through a modifier rather than a `GeometryReader` container avoids the keyboard-driven layout loop, while the explicit width threshold preserves the iPad landscape three-column layout. The recorded height keeps the tallest value seen at the current width, so the keyboard's reduced height cannot drop the board into the short-height fallback and tear down a focused search field; rotation changes the width and records a fresh height. The grouping tab resigns its TextEditor before the BO3 tab is selected, and the BO3 board ignores the keyboard safe area.

The arena header combines the score and the current turn into one light card:

```
+------------------------------------[第2局]--+
| [3][5][7][8]       [1][2][4][6]            |
| 红方          0 : 0          紫方           |
| * A队                        B队 *          |
|--------------------------------------------|
| * A队 禁用                     BAN 2 / 2    |
| 第2局 · 第7/12手                            |
| [01 A禁][02 B禁][03 A选][04 B选] ...  →     |
+--------------------------------------------+
```

On iPhone the game number is a top-right capsule overlay instead of a dedicated row, the score typography and padding are reduced, and the timeline collapses to a one-row horizontal strip inside the current-turn card. This gives the hero grid the maximum remaining height. iPad keeps the full-size score row and the separate two-row timeline.

Visual decisions:

- The arena card uses the system secondary grouped background, semantic primary/secondary text, a subtle gold hairline, and the app's blue tint for primary actions. Team A/B use red/violet ink colors for readable labels and the brighter red/violet for fills and pips; gold is reserved for series/champion accents.
- Seat numbers are enlarged and shown once in the center, with team A's seats on the left and team B's seats on the right; the redundant per-team seat rows are removed from the side blocks.
- The rules hero uses a light card with a soft gold tint and a gold hairline instead of a dark gradient.
- The rest of the screen keeps the existing system grouped background, secondary cards, 18 pt radius, and blue interactive tint. Team colors identify sides; blue remains the action color.
- The hero card uses a 13 pt rounded-square avatar, a 2 pt element ring, a tiny top-right role tag, a top-left used badge, and the character name below. Used cards are muted/grayscale with a dashed border, matching the reference intent without copying its full dark skin.
- The timeline uses numbered chips grouped by phase. Current step gets a gold border and a subtle pulse; completed steps show the hero name; pending steps show a dash.
- The lineup strip shows two ban tiles and four pick tiles per team. Bans get a slash overlay; picks show the portrait. On very narrow widths the strip scrolls horizontally.
- The pool header is a horizontally scrolling role-chip row plus an availability toggle and a collapsible search field. Pool stats ("used / prior locks / available") sit under the grid or at the end of the header.
- Sheets: settings and rules are large sheets; history is a medium/large sheet. Reset uses a destructive confirmation dialog.
- Toast is a top capsule overlay with success/warning/info tones. Haptics: light impact on a recorded action, success notification on a winner, warning notification on a locked tap.
- Reduce Motion disables the score bump and step pulse. Dynamic Type is capped for the dense board chips; accessibility sizes switch the board to a fully scrolling presentation instead of a fixed header.

Alternative considered: a fixed dark arena/rules skin. It is closer to the reference page but requires custom versions of every control, makes the tab switch visually jarring, and doubles the contrast/accessibility work. The chosen light native board keeps the app's existing component language and uses team colors and a restrained gold accent for the BO3 identity.

### 11. Settings, rules, and history

- Settings sheet: team names (trim, 16-character cap, fallback to "A 队"/"B 队"), a `TextEditor` bound to a local draft of the shared pool, parsed pool health, game-3 no-ban toggle, restore-default action, and apply/cancel. Apply validates the draft; invalid or under-12 pools are rejected and the previous pool is kept. Pool changes are committed on apply, not per keystroke.
- Pool health reports the 12/24/28 thresholds and duplicate characters. It also reports whether the remaining distinct pool can start the next game.
- Rules sheet: the 12-step and 8-step flow chips, global-BP explanation, position guidance, reset behavior, avatar attribution, and an unofficial-tool disclaimer.
- History sheet: one card per completed prior game, with both teams' bans/picks and the result. It is read-only.

### 12. Testing strategy

- `Bo3DraftEngineTests`: exact sequences, game-3 filter parity, current/global availability, current-game duplicate rejection, winner gating, series over, reopen, undo order, seat validity, start/next-game gating, and every sanitization branch.
- `Bo3PoolTests`: category order, cross-category deduplication, duplicate reporting, role lookup, empty categories, and shared-parser compatibility.
- `Bo3SeriesStoreTests`: save/load round trip, no-series default, corrupt payload, future-game reset, invalid-seat repair, and persistence after each mutation.
- `Bo3AvatarCatalogTests`: index count is 131, all files referenced by the index exist, aliases resolve, all default-34 characters except `点刀` resolve, unknown names produce a fallback descriptor, and element colors are present.
- `GroupingEngineTests` updates:
  - Default pool parser counts become `[7, 6, 8, 13]`.
  - The fixed-seed cross-client test passes an explicit `legacyWebPoolText` (the old 30-character pool) so it continues to verify algorithm parity with the web client.
  - A new seeded test verifies the 34-character default produces a complete, deterministic assignment.
  - The bundled preset test expects 34 characters, the exact pool text, and spot-checks 魈/ Jungle, 琴/ Mid, and the four added warriors.
  - A new test asserts `imported.poolText == GroupingEngine.defaultPoolText`.
- `AppBootstrapTests`: pending marker applies 34 on a fresh install; a known legacy default pool is upgraded; a pre-marker custom pool and weights are preserved and the migration is marked handled; existing marker preserves a user pool; invalid resource leaves the marker pending, keeps a usable default, and retries successfully on the next launch; the function is idempotent.
- Manual validation: iPhone SE, iPhone 16 Pro portrait/landscape, iPad 11-inch portrait/landscape, light/dark, largest accessibility text, Reduce Motion.

## Risks / Trade-offs

- **The 34-character default changes grouping results for fresh installs and "restore default".** → Keep the cross-client fixed-seed test on an explicit old-30 fixture, add a separate 34-default test, and accept that iOS fresh-install grouping differs from Android/web until those follow up.
- **The bundled preset keeps its old marker while its payload changes.** → Document the supersession in the release notes; the marker means "applied once", not "v2 content". Custom pools from pre-marker upgrades are preserved; only fresh installs and known built-in defaults receive 34.
- **The unarchived `add-role-lane-weights` change still describes a 30-character preset.** → Do not edit that change here. Archive it before this change, or reconcile its preset requirement at archive time. The new `role-pool-defaults` capability owns the 34-character behavior going forward.
- **Avatar licensing and attribution.** → Keep the "头像：原神观测枢" credit and an unofficial-tool disclaimer in the rules sheet; no network access is added. The user owns the decision to ship the reference portraits.
- **96x96 portraits are soft at 3x on large cards.** → Use the portraits at 44-64 pt, where 96 px is adequate; do not upscale. Higher-resolution sources can replace the generated files later without changing the index format.
- **Dense UI on small phones and large Dynamic Type.** → Cap dense chip text sizes, let the board switch to a fully scrolling presentation at accessibility sizes, and test the SE-class height.
- **A restored BO3 tab on first launch could see an uninitialized pool.** → Move the preset bootstrap to `MobaRandomApp.init` before either tab body and test the launch scenario.
- **Invalid persisted state could produce an inconsistent board.** → Port the prefix/sanitization rules and cover each branch with tests; never trust a saved winner whose action count is incomplete.
- **Image decoding or resource lookup can fail.** → The catalog returns a fallback descriptor instead of throwing; a missing file is a visual fallback, not a crash.
- **Chinese resource names and Xcode resource handling.** → Generated files use ASCII ids; a folder reference preserves the directory structure.
- **Multiple iPad windows sharing one series key.** → The app is a single-series utility; concurrent windows would share the same draft. This is acceptable for now and can be revisited if multi-window becomes a real use case.

## Migration Plan

1. Add the `Bo3Series` model, engine, store, and `moba_bo3_series_v1` key. No existing data is migrated; an absent key means "no series".
2. Update `GroupingEngine.defaultPoolText` and `default-role-weights-v2.json` to the 34-character roster. Keep the existing marker and resource name.
3. Extract the preset migration into `AppBootstrap` and call it from `MobaRandomApp.init`; remove the duplicate call from `ContentView.onAppear`.
4. Generate the avatar resources and index; add the XcodeGen folder reference; regenerate the project.
5. Add the root tab shell and BO3 feature module; leave `ContentView` behavior unchanged.
6. Update and add tests; run the iOS test suite.
7. Update the README feature list and validation commands.
8. Release with a version bump. Rollback is binary-only: the old binary ignores `moba_bo3_series_v1`; the pool and weight keys remain compatible.

Archive coordination: `add-role-lane-weights` is complete but not archived. Archive it before this change if possible so its 30-character preset requirement is written into the main spec history before `role-pool-defaults` supersedes it; otherwise reconcile that requirement when archiving.

## Open Questions

- Does the group have an official alias or portrait for `点刀`? It currently falls back to the gradient tile.
- When should Android and web receive the same 34-character default and BO3 parity?
- Is a long-term archive of past series needed, or is the current series plus its per-game history enough?
- Should the iPad board support hardware-keyboard shortcuts beyond undo (for example number keys for steps)?
