# Design

## Context

The Android app is a single `MainActivity` built with XML and imperative Views. It already has a shared role-pool text, a weight editor, local history, and a tested Kotlin grouping engine. It has no fragments, no navigation graph, no image-loading library, and no BO3 code.

The iOS BO3 board is a SwiftUI feature backed by a pure Swift rules engine, a JSON series store, and 132 bundled WebP avatar files plus an alias index. The durable `bo3-global-draft` and `role-pool-defaults` specs define the behavior; this design maps that behavior onto Android's existing stack. See `proposal.md` for motivation.

Constraints:

- `minSdk` is 30 and `targetSdk` is 36; the app is fully offline and declares no network permission.
- Material 3 and AppCompat are already present. Compose is not.
- The role pool is stored in `moba_random_preferences` under `moba_role_pool`; the bundled preset marker is `moba_builtin_weight_preset_v2_applied`.
- Android's current default pool has 30 characters; iOS and the specs require 34.
- Tablet/phone classification must use global screen dimensions, not a per-window size class.
- The durable `bo3-global-draft` Purpose still says "native iOS"; reword it to cover both native clients during the archive sync.

## Goals / Non-Goals

**Goals:**

- Add a real two-tab Android shell without rewriting the grouping screen.
- Match the iOS BO3 rules, state transitions, board regions, and persistence behavior.
- Make the board usable on phone portrait, phone landscape, tablet portrait, and tablet landscape.
- Bring the Android shared default pool and preset migration to 34 characters.
- Keep the rules engine testable without an Android device or emulator.

**Non-Goals:**

- Cross-device sync or sharing a series between iOS and Android.
- Compose migration, a full fragment/navigation refactor, or a new architecture for the grouping screen.
- Pixel-identical cross-platform styling; Android uses Material 3 equivalents of the iOS light board.
- Multi-window/window-size-class layout adaptation beyond the requested global screen-size inference.
- Changing the iOS implementation or its stored data.

## Decisions

### 1. Bottom navigation with two persistent containers

`MainActivity` becomes the shell:

```text
MainActivity
  +-- FrameLayout groupingContainer
  |     +-- existing NestedScrollView content
  +-- FrameLayout bo3Container
  |     +-- Bo3BoardView (created lazily)
  +-- BottomNavigationView [随机] [BO3]
```

The existing grouping XML is moved under `groupingContainer` unchanged. The BO3 tab is a custom `Bo3BoardView` added to `bo3Container`; it owns its own state and renders all board regions.

Why not fragments: the app has no fragment or navigation infrastructure, and converting the 454-line grouping activity would add lifecycle and state-restoration churn unrelated to BO3. Why not a separate `Bo3Activity`: it would not preserve the two-tab feel and would require duplicating the pool/bootstrap lifecycle. The two-container shell is the smallest change that still behaves like the iOS tab bar.

The selected tab is stored in the same preferences file. When switching to BO3, the grouping editor clears focus and hides the keyboard before the board is shown, avoiding the keyboard/layout interaction seen on iOS. The BO3 board reads the shared pool every time it becomes visible.

Alternative considered: a `ViewPager2` with two pages. It adds swipe behavior that the iOS tab bar does not have and keeps both complex screens measured continuously; the visibility toggle is simpler.

### 2. Pure Kotlin rules engine, separate from Android classes

Port the Swift models and engine as plain Kotlin:

```text
Bo3Team / Bo3ActionType / Bo3Step / Bo3Action
Bo3Game / Bo3Seats / Bo3TeamNames / Bo3Series
Bo3Pool
Bo3DraftEngine (object)
```

`Bo3DraftEngine` mirrors the Swift invariants:

- game 1 uses the 12-step sequence; game 2 mirrors every team assignment; game 3 uses the 8-pick sequence only when the started game's `noBan` flag or the series setting is true;
- a hero is unavailable if it appears in the active game or was picked in an earlier game; earlier bans are free;
- winners require a complete draft; undo clears a winner before removing an action;
- seats are a random 4/4 split of 1...8;
- next-game gating counts pool heroes that are not globally locked, not raw previous-pick count (so removed picks are not double-subtracted).

The engine has no Android imports and is tested on the JVM. This is a direct port of proven Swift logic, not a reinterpretation.

Alternative considered: reuse the HTML JavaScript through a WebView. Rejected: it would duplicate the UI, lose native persistence/accessibility, and couple the app to a reference page.

### 3. SharedPreferences JSON store with sanitize-on-load

`Bo3SeriesStore` wraps a `Bo3Series`, persists it as JSON under `moba_bo3_series_v1`, and exposes the same mutation methods as the iOS store. Every mutation follows:

```text
copy series -> engine validates/mutates copy -> replace series -> save -> notify board
```

On load, the store decodes and runs `Bo3DraftEngine.sanitize`. Invalid version/current game/corrupt JSON yields an empty series. The sanitizer keeps the valid action prefix, drops incomplete winners, clears future games, repairs seats, and normalizes team names. The role pool is never included in the series payload.

Why `org.json` and not a new serialization dependency: the app already uses `org.json` for history and weight import/export. The schema is small and versioned. A pure `Bo3SeriesCodec` handles encode/decode and is separated from the thin `SharedPreferences` wrapper so it can be tested on the JVM with a test-only `org.json` implementation. The store can be replaced later without touching the engine.

Alternative considered: Robolectric for store tests. It adds a much heavier test runtime for a small JSON schema; a pure codec plus manual persistence checks gives the same confidence with less setup.

### 4. Screen-size layout matrix

Layout mode is resolved from the global configuration:

```text
width  = resources.configuration.screenWidthDp
height = resources.configuration.screenHeightDp

width >= 900 && height >= 600  -> THREE_COLUMN
width >= 600                   -> TWO_COLUMN
otherwise                      -> COMPACT
```

Mapping:

```text
COMPACT           phone portrait, one scrolling board column
TWO_COLUMN        tablet portrait or phone landscape: controls | hero grid
THREE_COLUMN      tablet landscape: team A | center board | team B
```

The compact mode uses the tight header: reduced score typography/padding, game number as a top-right badge, and the timeline as a one-row horizontal strip inside the current-turn card. Two/three-column modes use the full header and, where height permits, a separate timeline card. The 34-character grid uses a `GridLayoutManager` whose span count is derived from width (4 on phones, 6 on tablet portrait, 8 on tablet landscape), clamped so names remain readable.

Why not `smallestScreenWidthDp`: it identifies device class but does not change with orientation, so phone landscape would stay classified as a phone and miss the two-column opportunity. The request explicitly accepts global current screen dimensions. Multi-window/foldable edge cases are accepted as out of scope.

Alternative considered: auto-fit grids/`FlexboxLayout`. Adds a dependency and makes the layout less predictable than width-based spans.

### 5. Reuse the existing avatar assets and loader pattern

Run the existing generator with the Android asset target:

```bash
python3 scripts/extract_bo3_avatars.py htmls/moba-bo3-draft.html \
  --output MobaRandomAndroid/app/src/main/assets/BO3
```

`Bo3AvatarRepository` reads `assets/BO3/avatar-index.json`, resolves aliases, decodes WebP via `BitmapFactory`, and caches bitmaps in an `LruCache`. Decoding happens on a small executor; the UI receives a callback on the main thread and shows a gradient/first-character fallback until then or for unknown names. A reusable `Bo3AvatarView` (FrameLayout with image + fallback text) is used by the grid, lineup, timeline, team panels, and history.

Why not Glide/Coil: the assets are local, small, and bounded; a focused loader avoids a new dependency and keeps the offline build simple. Why not bundle PNG copies: WebP is supported at `minSdk 30` and avoids doubling the asset size.

### 6. Android 34-character roster and migration policy

Replace `GroupingEngine.DEFAULT_POOL_TEXT` with the iOS 34-character roster and replace `app/src/main/res/raw/default_role_weights_v2.json` with the iOS payload. Keep the existing preset marker/resource name so it remains a one-time migration.

`RoleWeightStorage.applyBuiltInPresetIfNeeded` becomes a policy plus an applier:

```text
no stored pool                         -> write 34 default, apply preset
marker present                         -> leave pool and weights unchanged
stored pool is a known built-in default -> apply preset (upgrades 30 -> 34)
stored pool is custom                   -> preserve pool/weights, mark handled
preset missing or invalid               -> keep usable pool, leave marker pending
```

Known built-in defaults are compared after normalizing line endings and per-line whitespace. The list includes the Android 30 default, the iOS legacy 32/29 rosters, the reference-page 34 variants, and the current 34 default. The policy is extracted into a pure function so JVM tests cover every branch without a device.

Existing Android users whose marker is already set keep their current 30-character pool, matching the "preserve an upgraded installation" rule on iOS. Fresh installs and users who never left a known built-in default get 34.

Alternative considered: force every Android install to 34. Rejected because it would overwrite custom pools and contradict the shared spec.

### 7. Board composition and Android view mapping

```text
Bo3BoardView
  +-- Bo3HeaderView          score, seats, current turn, embedded strip
  +-- Bo3TimelineView        full 12/8-step sequence on wider layouts
  +-- Bo3LineupStrip         two rows of 2 bans + 4 picks
  +-- Bo3TeamPanelView       tablet landscape side panels with prior games
  +-- Bo3PoolBar             role chips, availability toggle, search, stats
  +-- RecyclerView           hero grid with Bo3HeroAdapter
  +-- dialogs/activities     settings, rules, history, reset confirmation
```

The header is a state-driven custom view with five states: start, drafting, pending winner, game complete, champion. The hero adapter renders avatar, name, recommended role, and a used/locked badge; locked cards are muted and non-clickable with a lock explanation. The pool bar reuses `ChipGroup` single selection and a collapsible `TextInputLayout` search field.

Settings use a dedicated `Bo3SettingsActivity` because the pool editor and validation need space and a keyboard. Rules use a scrollable activity/dialog with the three flow grids and attribution. History uses a read-only dialog/activity with prior-game bans, picks, and result.

### 8. Testing strategy

- JVM unit tests for `Bo3DraftEngine`: sequences, game-2 mirror, game-3 no-ban, locks, winner, undo, seats, gating (including removed-pool picks), sanitization.
- JVM tests for `Bo3Pool`, `Bo3SeriesCodec`, layout-mode resolution, and the 34-roster/preset policy. The codec tests use a test-only `org.json` implementation; no runtime dependency is added.
- Update grouping tests: default counts `[7, 6, 8, 13]`; keep the old 30 roster as an explicit legacy fixture for the cross-client seed test; add a 34-default deterministic test.
- Manual UI validation on the existing phone/tablet AVDs: phone portrait/landscape switch, tablet portrait/landscape, settings/rules/history, process recreation, and a full three-game series.
- Instrumentation/Espresso is not required for the first implementation because the project has no UI-test infrastructure; the board's behavior is covered by engine/policy/codec tests plus manual checks. If a regression-prone flow emerges, add focused instrumentation later.

## Risks / Trade-offs

- **Large UI surface (header, timeline, lineup, panels, grid, dialogs)** -> Build reusable custom views and a single state-driven render path; implement and validate one layout mode at a time.
- **Avatar decoding jank or memory pressure** -> Background decode, bounded `LruCache`, decode at the displayed size, and fallback tiles.
- **Global screen-size inference differs from multi-window reality** -> Accept the requested simplification; keep the layout resolver isolated so a future window-size implementation can replace it.
- **34-roster migration can overwrite custom pools** -> Pure policy tests and the known-default allowlist; custom pools are marked handled and preserved.
- **Changing the default roster changes grouping output for fresh/legacy-default installs** -> Keep the old 30 roster as a test fixture, add a separate 34 test, and document the intentional behavior change.
- **Android dark theme vs iOS light board** -> Use Material 3 DayNight tokens and BO3-specific team/gold accents in both `values` and `values-night`; do not hard-code light surfaces.
- **Tab switch while the grouping keyboard is open** -> Clear focus and hide the IME before showing BO3, then let the board measure its own container.
- **No existing Android UI test harness** -> Rely on engine/policy tests plus manual AVD validation for this change; add Espresso only for a discovered regression.
- **Another active change still describes the old 30-character preset** -> `add-role-lane-weights` is complete but unarchived and its `role-lane-weighting` spec still contains the earlier 30-character preset requirement. Do not edit that change here; archive it first or reconcile that requirement at its archive time. `role-pool-defaults` owns the 34-character behavior going forward.

## Migration Plan

1. Update the Android default pool and bundled preset to 34; add the pure migration policy and its tests before wiring it into `RoleWeightStorage`.
2. Add the BO3 models, engine, and store with JVM tests; no UI dependency.
3. Add avatar assets/index and the repository; verify a sample of aliases and fallbacks.
4. Add the two-tab shell and phone-portrait board; validate start, pick, undo, winner, and relaunch.
5. Add two- and three-column layouts plus team panels; validate on tablet AVDs.
6. Add settings, rules, history, and the full-series manual pass.
7. Run the Android unit-test suite and record manual validation results.

Rollback: the BO3 code and assets can be removed independently. The new series key is additive. Reverting the roster migration after it has run will not restore a user's previous 30-character pool automatically; release notes should state that the roster upgrade is one-way for fresh/legacy-default installs.

## Open Questions

None at planning time. The phone/tablet thresholds and the 34-character migration policy are fixed by this design; any later change to them should be a new change.
