# Tasks

## 1. Shared roster and startup bootstrap

- [x] 1.1 Replace `GroupingEngine.defaultPoolText` with the 34-character reference roster (射手 7, 打野 6, 中路 8, 战士 13). Verify: update the default-pool parser test to expect `[7, 6, 8, 13]` and assert the presence of 赛索斯, 杜林, 法尔加, 克洛林德, 赛诺, 八重, 魈 under 打野, and 琴 under 中路; run the test.
- [x] 1.2 Update `MobaRandom/Resources/default-role-weights-v2.json` to 34 characters: add 杜林, 法尔加, 克洛林德, 赛诺 at weight 100 战士; move 魈 to 打野 and 琴 to 中路 with one-hot vectors; keep every other vector unchanged. Verify: the preset import test passes, every character totals 100, and the derived pool text has 34 names.
- [x] 1.3 Add a test asserting `BuiltInWeightPresetMigration.load(...).poolText == GroupingEngine.defaultPoolText`. Verify: the new equality test passes and fails if either roster is edited without the other.
- [x] 1.4 Extract the preset migration into `AppBootstrap.applyBuiltInWeightPresetIfNeeded(defaults:)`, call it from `MobaRandomApp.init`, and remove the duplicate `ContentView.onAppear` call. Verify: tests cover a pending marker on a fresh install (applies 34), a known legacy default pool (upgrades to 34), a pre-marker custom pool (preserved and marked handled), an existing marker (preserves a custom pool), an invalid resource (marker stays pending, pool remains usable, next launch retries successfully), and an idempotent second launch.
- [x] 1.5 Keep the fixed-seed cross-client test on an explicit `legacyWebPoolText` fixture containing the old 30-character pool, and add a separate seeded deterministic test for the new 34-character default. Verify: the old expected assignment still passes against the fixture, and the new test produces four unique roles per team.
- [x] 1.6 Document the 34-character default, the retained v2 marker, and the fact that custom pools/weights from upgrades are preserved while known legacy defaults are upgraded in `README.md`. Verify: the README section is present and its listed iOS test command still passes.

## 2. BO3 engine

- [x] 2.1 Add `Bo3Team`, `Bo3ActionType`, `Bo3Step`, `Bo3Action`, `Bo3Game`, `Bo3Seats`, `Bo3TeamNames`, and `Bo3Series`. Add the game-1 12-step, game-2 mirrored A/B 12-step, and 8-pick constants. Verify: tests assert every step's team/type, the 8-pick constant equals the pick-only filter of the game-1 constant, and game 2 swaps every team while preserving step types.
- [x] 2.2 Implement sequence resolution for games 1-3, including the game-2 mirrored A/B order and the started-game `noBan` flag taking precedence over the series setting. Verify: tests cover game 1, game 2 mirrored teams, game 3 before start, game 3 after start, and a deferred setting change.
- [x] 2.3 Implement availability: current-game bans and picks lock, prior-game picks lock, prior-game bans do not lock, and current-game takes precedence for messaging. Verify: tests cover each case, including a hero removed from and re-added to the pool.
- [x] 2.4 Implement series wins, champion detection, winner recording, winner reopening, and the rule that a winner requires a complete draft. Verify: tests cover a 2-0 series, a 2-1 series, reopening the final winner, and rejecting an early winner.
- [x] 2.5 Implement undo with winner-first ordering and active-game-only scope. Verify: tests cover undo winner, undo action, empty undo, and no changes to prior games.
- [x] 2.6 Implement seat generation and validation: a random 4/4 split of 1...8, uniqueness, four seats per team, and regeneration on reset. Verify: tests run many generations, assert every split covers 1...8 exactly once, and reject malformed seats.
- [x] 2.7 Add the `Bo3Pool` wrapper over `GroupingEngine.parseRolePool`: preserve category order, keep the first occurrence across categories, report duplicates, map hero to recommended role, and omit empty categories from filter data. Verify: tests cover order, duplicates, empty categories, and shared-parser compatibility.
- [x] 2.8 Implement start and next-game gating plus pool health: 12 distinct minimum to start, remaining-unlocked count versus the next sequence length, and the 12/24/28 health thresholds. Verify: tests cover a 11-character pool, 12, 23/24, 27/28, and an insufficient remaining pool before game 3.
- [x] 2.9 Implement series sanitization for corrupt JSON, version mismatch, out-of-range `currentGame`, invalid action prefixes, incomplete winners, future-game reset, and invalid seats. Verify: one test per branch, including a duplicate action that must truncate the prefix rather than skip the bad action.
- [x] 2.10 Add engine-level documentation comments for the sequence, availability, and sanitization invariants. Verify: `xcodebuild test` builds without warnings from the new engine files.

## 3. Series store and persistence

- [x] 3.1 Add `Bo3SeriesStore` (`@MainActor @Observable`) with an injectable `UserDefaults`, a versioned `moba_bo3_series_v1` payload, load-on-init, and a single save path. Verify: tests round-trip a series and load the empty default when the key is absent.
- [x] 3.2 Route every mutation through the store and save immediately; also save on scene background. Verify: a test mutates, recreates the store, and observes the same state; manual background/foreground preserves the draft.
- [x] 3.3 Verify the store applies engine sanitization on load for corrupt payloads, future games, and invalid seats instead of exposing inconsistent state. Verify: store tests assert the sanitized result for each case.

## 4. Avatar assets and catalog

- [x] 4.1 Add `scripts/extract_bo3_avatars.py` that takes the reference HTML path, decodes the 131 WebP images, writes deterministic ASCII ids, and emits `avatar-index.json` with aliases, elements, and file ids. Verify: run it twice and compare checksums; assert 131 images and 131 index entries.
- [x] 4.2 Commit the generated `MobaRandom/Resources/BO3/avatars/*.webp` and `avatar-index.json`; add an XcodeGen folder reference with `buildPhase: resources` and exclude the folder from the parent source entry. Verify: `xcodegen generate` succeeds and the built app bundle contains the index and all image files under `BO3/avatars`.
- [x] 4.3 Implement `Bo3AvatarCatalog` to load the index once, resolve alias -> official -> file, expose element colors, and cache decoded images with `NSCache`. Verify: tests assert the index count, alias resolution, all default-34 characters except 点刀 resolving, and a nil image for an unknown name.
- [x] 4.4 Implement the fallback descriptor (stable hash, two HSL stops, first character) and the avatar view with the element ring, rounded-square crop, and used-state grayscale. Verify: previews or snapshots for a known hero, an alias, `点刀`, and an unknown custom name.
- [x] 4.5 Add role-color and element-color helpers, including the reference base palette and stable extras for custom roles. Verify: tests cover 射手/打野/中路/战士/辅助/坦克 and a custom role.
- [x] 4.6 Add a short usage/provenance header to the extraction script and note that the reference HTML is not committed. Verify: the script prints usage when run without an argument and fails with a clear message for a missing file.

## 5. Root tab and BO3 board

- [x] 5.1 Add `RootTabView` with "随机" and "BO3" tabs, each owning a `NavigationStack`; persist the selected tab in `@AppStorage`. Verify: the app launches on the random tab, switches to BO3, and returns to the same tab after relaunch.
- [x] 5.2 Add `Bo3DraftView` with the shared pool binding, series store, navigation title, and direct toolbar icons for rules, undo, reset, history, and settings (no overflow menu). Verify: the tab is reachable, the toolbar actions open their destinations, and undo/reset reflect availability.
- [x] 5.3 Add `Bo3ArenaHeader` for the no-series, drafting, pending-winner, game-complete, and champion states, including score, game number, seats, current team/type, and step progress. Verify: previews/manual checks for each state and a 1:0, 1:1, and 2:0 score.
- [x] 5.4 Add `Bo3Timeline` with 12/8 steps, completed hero names, current-step highlight, pending state, and phase grouping; use a one-row scrollable strip on compact width and the full layout elsewhere. Verify: previews for game 1, game 3 no-ban, mid-draft, and complete; the order stays correct in both modes.
- [x] 5.5 Add `Bo3LineupStrip` with two ban tiles and four pick tiles per team, empty/filled states, team colors, and ban/pick distinction. Verify: previews for an empty game, a mid-draft game, and a complete game.
- [x] 5.6 Add `Bo3HeroGrid` with the avatar card, name, recommended role, used badge, grayscale used state, and tap-to-select. Verify: a tap records the current step, a tap on a locked hero shows the correct current/global reason, and a tap with no active step does not record.
- [x] 5.7 Add role chips, search, only-available, empty-state clearing, and pool stats. Verify: filter counts match the pool, a search narrows the grid, only-available hides all locks, and clearing restores the full grid.
- [x] 5.8 Wire the primary actions: start game 1, start next game, record winner, reopen winner, and reset confirmation. Verify: a full manual game 1 -> winner -> game 2 flow, a 2-0 champion flow, and a reset that preserves pool/team names/settings.

## 6. Settings, rules, history, and feedback

- [x] 6.1 Add the settings sheet's team-name fields and game-3 no-ban toggle, including empty-name fallback and the deferred-change hint after game 3 starts. Verify: apply non-empty/empty names, change the rule before and after game 3, and confirm the active game keeps its original sequence.
- [x] 6.2 Add the shared pool editor, parsed preview, duplicate report, restore-default action, and pool health. Verify: a valid edit updates the grouping tab, a <12 pool is rejected, duplicates are reported, and restore changes the draft text only until apply.
- [x] 6.3 Add the rules sheet with the 12-step and 8-step flows, global-BP copy, position guidance, reset behavior, avatar attribution, and unofficial-tool disclaimer. Verify: every section is present and the attribution link opens the reference source.
- [x] 6.4 Add the series-history sheet with prior-game bans, picks, and result, plus the empty state. Verify: game 1 shows the empty state, game 2 shows game 1, and prior records are read-only.
- [x] 6.5 Add the toast overlay and haptics, and respect Reduce Motion. Verify: locked taps warn, successful picks click, a winner succeeds, and motion is reduced when the system setting is on.
- [x] 6.6 Add VoiceOver labels/hints for the arena, timeline, lineup, hero cards, and filters, and cap dense board text sizes. Verify: VoiceOver reads the current step and used state, and the largest accessibility size switches the board to a scrolling presentation.

## 7. Responsive layouts

- [x] 7.1 Verify the compact iPhone portrait layout keeps the arena header, embedded timeline strip, lineup, pool header, and scrollable grid usable at iPhone SE and iPhone 16 Pro sizes, with the game number as an overlay and the hero grid maximized. Verify: manual checks on both simulators in light and dark mode.
- [x] 7.2 Add the two-column layout for iPhone landscape and iPad portrait, keeping the draft controls and grid visible. Verify: rotate the iPhone and iPad, complete a pick in each orientation, and confirm no controls are clipped.
- [x] 7.3 Add the iPad landscape three-column layout with full team panels on both sides. Verify: complete a draft on an 11-inch iPad landscape and compare the score/lineup with the phone layout.
- [x] 7.4 Verify the accessibility-size fallback scrolls the whole board rather than truncating the fixed header. Verify: largest Dynamic Type on iPhone SE and iPad portrait, with every control still reachable.

## 8. Integration checks

- [x] 8.1 Run the full iOS test suite with `xcodebuild -project MobaRandom.xcodeproj -scheme MobaRandom -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO test`. Verify: all existing and new tests pass.
- [x] 8.2 Build and smoke-test the app in the simulator across the four layouts and both appearances, including a full 3-game series and a reset. Verify: no crash, no clipped controls, and the persisted series restores after relaunch.
- [x] 8.3 Update `README.md` with the BO3 feature list, the shared 34-character default, the iOS-only scope of this change, and the validation commands. Verify: the documented commands run as written.
- [x] 8.4 Confirm the app change is iOS-only: no Android or grouping-web source files are modified. The reference BO3 HTML is expected to change as a separate sync. Verify: `git diff --stat` shows iOS, asset, script, test, documentation, and reference-HTML paths only.

## Workflow follow-up

- Archive `add-role-lane-weights` before this change if possible, or reconcile its 30-character preset requirement when archiving.
- Run `openspec validate "add-bo3-draft-tab"` and archive this change after review.
- Bump the iOS version and prepare the App Store release notes outside this change.
