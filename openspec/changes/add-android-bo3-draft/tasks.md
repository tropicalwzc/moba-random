# Tasks

## 1. Shared 34-character roster and preset migration

- [x] 1.1 Replace `GroupingEngine.DEFAULT_POOL_TEXT` with the iOS 34-character roster (7 射手 / 6 打野 / 8 中路 / 13 战士) and update the parser test to assert `[7, 6, 8, 13]`, 赛索斯, 魈 under 打野, 琴 and 八重 under 中路, and the four added warriors. Verify: the updated parser test passes.
- [x] 1.2 Replace `app/src/main/res/raw/default_role_weights_v2.json` with the iOS 34-character payload and add a test that importing it yields 34 characters and a derived pool equal to `DEFAULT_POOL_TEXT`. Verify: the preset import test passes and every character totals 100.
- [x] 1.3 Add a pure migration-policy helper that normalizes pool text, recognizes known built-in defaults (Android 30, iOS legacy 32/29, reference-page 34 variants, current 34), and returns apply / preserve-custom / already-applied. Verify: JVM tests cover every branch without an Android device.
- [x] 1.4 Wire the policy into `RoleWeightStorage.applyBuiltInPresetIfNeeded` so fresh installs and known defaults upgrade to 34 while pre-marker custom pools and weights are preserved and marked handled. Verify: tests cover fresh install, Android legacy 30 upgrade, custom preservation, existing marker, invalid preset, and retry after failure.
- [x] 1.5 Keep the old 30-character roster as an explicit legacy fixture for the cross-client fixed-seed test and add a separate deterministic test for the 34-character default. Verify: both tests pass and the old expected assignment remains unchanged against the fixture.
- [x] 1.6 Document the Android 34-character default and the preserve-custom upgrade rule in `MobaRandomAndroid/README.md` and the root `README.md`. Verify: both documents describe fresh/legacy upgrades, custom preservation, and the unchanged group-3 rule.

## 2. BO3 domain model and rules engine

- [x] 2.1 Add Kotlin BO3 domain types for team, action type, step, action, game, seats, team names, and series with the same defaults and version as iOS. Verify: a JVM test constructs a default series and asserts 3 empty games and no active game.
- [x] 2.2 Add `Bo3Pool` with cross-category deduplication, role lookup, total count, and duplicate reporting. Verify: tests cover duplicate names, category order, and unknown lookups.
- [x] 2.3 Port the game-1 12-step sequence, the fully mirrored game-2 sequence, and the 8-pick no-ban game-3 sequence, plus sequence resolution for all games. Verify: tests assert every team/type, the game-3 pick-only relationship, and the started-game `noBan` precedence.
- [x] 2.4 Port availability, current-step lookup, and lock explanations so current-game actions are checked before earlier picks and earlier bans remain available. Verify: tests cover current/global locks, released bans, and the lock messages.
- [x] 2.5 Port series lifecycle operations: start game 1, start the next game, reset, winner judgment, winner reopening, and undo. Verify: tests cover early-winner rejection, winner-first undo, action undo, and prior-game isolation.
- [x] 2.6 Port seat generation/validation, pool minimums, and next-game gating, counting only pool heroes that are not globally locked. Verify: tests cover 4/4 seats, small pools, insufficient remaining picks, and picked heroes removed from the pool.
- [x] 2.7 Port defensive sanitization for version mismatch, out-of-range current game, invalid action prefix, duplicate heroes, incomplete winners, future games, invalid seats, and team-name normalization. Verify: tests cover each repair path and confirm corrupt input never crashes.

## 3. Series persistence

- [x] 3.1 Add a pure `Bo3SeriesCodec` plus a thin `Bo3SeriesStore` backed by `SharedPreferences` under `moba_bo3_series_v1`, with save after every mutation, reset, and sanitize-on-load. Add the test-only `org.json` implementation if needed. Verify: JVM codec tests cover round trip, corrupt JSON fallback, invalid version, and future-game clearing; manual verification covers SharedPreferences persistence.
- [x] 3.2 Keep the shared role-pool text outside the series payload and expose a refresh path for the board when the pool changes. Verify: a test changes the pool and confirms the saved series JSON does not contain the pool and the board reloads the new categories.

## 4. Avatar assets and rendering

- [x] 4.1 Generate the shared avatars into `MobaRandomAndroid/app/src/main/assets/BO3` using `scripts/extract_bo3_avatars.py` and verify `avatar-index.json` loads 131 avatars plus aliases. Verify: the generated file count matches the iOS assets and a sample of aliases resolves.
- [x] 4.2 Add `Bo3AvatarRepository` with asset lookup, alias resolution, element colors, deterministic fallback seeds, background WebP decoding, and a bounded `LruCache`. Verify: tests cover alias/fallback decisions and manual checks show no main-thread stalls while scrolling.
- [x] 4.3 Add a reusable `Bo3AvatarView` with image, element ring, used/muted state, and gradient-letter fallback, and use it in the grid and lineup. Verify: a manual check covers known portraits, aliases, unknown names, and used cards.

## 5. Android two-tab shell

- [x] 5.1 Add the bottom navigation bar and grouping/BO3 containers to `MainActivity`, keeping the existing grouping screen and behavior intact. Verify: both tabs open, the grouping screen still generates groups, and switching back preserves its state.
- [x] 5.2 Persist the selected tab, restore it after relaunch, and clear grouping focus plus hide the keyboard before showing BO3. Verify: rotation/relaunch restores the tab and switching with the keyboard open does not clip or freeze the board.
- [x] 5.3 Run the bundled-preset bootstrap before either tab reads the pool, including a launch that restores BO3 directly. Verify: a fresh install opening BO3 sees the 34-character pool and preset weights.
- [x] 5.4 Declare the explicit RecyclerView dependency (if it is not already available transitively) and verify `./gradlew assembleDebug` resolves it.

## 6. Phone board

- [x] 6.1 Add the phone header with score, seats, current turn, game badge overlay, and embedded one-row timeline strip for start, drafting, pending-winner, game-complete, and champion states. Verify: a manual pass covers every state and the current step is highlighted.
- [x] 6.2 Add the roster filter/search bar, availability toggle, stats, and `RecyclerView` hero grid with used/locked badges and span sizing. Verify: filtering, search, only-available, clear filters, and locked-card taps behave as specified.
- [x] 6.3 Wire the board to the engine/store for start, pick, undo, winner, reopen, and reset. Verify: a full game 1 can be completed, the winner recorded, and the state restored after relaunch.
- [x] 6.4 Add start/next-game gating banners and lock explanations for small pools, insufficient remaining picks, current-game duplicates, and prior-game picks. Verify: each error is reachable in a manual test and states the correct counts.

## 7. Tablet and landscape layouts

- [x] 7.1 Add a pure layout-mode resolver using `screenWidthDp`/`screenHeightDp`: three columns at `>=900 && >=600`, two columns at `>=600`, compact otherwise. Verify: tests cover phone portrait, phone landscape, tablet portrait, tablet landscape, and the height guard.
- [x] 7.2 Implement the two-column board with scrollable controls on the left and hero grid on the right, including the full header and separate timeline when height permits. Verify: phone landscape and tablet portrait complete a pick without clipping controls.
- [x] 7.3 Implement the three-column board with full team panels on both sides, prior-game summaries, active-team highlighting, and the center header/timeline/grid. Verify: tablet landscape completes a full draft and the side panels match the center state.
- [x] 7.4 Verify every layout keeps filters, settings, rules, undo, reset, history, and winner controls reachable, and adjust grid spans for each width. Verify: a manual matrix covers phone portrait/landscape and tablet portrait/landscape.

## 8. Settings, rules, and history

- [x] 8.1 Add the BO3 settings screen for team names, shared pool editing, restore-default, game-3 no-ban rule, pool health, and validation. Verify: valid edits reach the grouping tab, too-small pools are rejected, and the no-ban change defers after game 3 starts.
- [x] 8.2 Add the rules reference with game-1, game-2, and no-ban flow grids, global-BP behavior, position guidance, reset behavior, and avatar attribution. Verify: content matches the iOS rules and the attribution link opens.
- [x] 8.3 Add the read-only series history with prior-game bans, picks, winners, and the empty state. Verify: game 1 appears after completion, no edits are possible, and the empty copy explains later-game locking.
- [x] 8.4 Add reset confirmation and toast/snackbar feedback for successful actions, locked selections, and validation failures. Verify: reset preserves pool/names/no-ban setting and every feedback path is visible.

## 9. Integration, tests, and documentation

- [x] 9.1 Run `cd MobaRandomAndroid && ./gradlew test` and confirm all JVM tests pass, including the new BO3, migration, layout, and roster tests.
- [x] 9.2 Run `cd MobaRandomAndroid && ./gradlew assembleDebug` and confirm the APK builds with the new assets and navigation resources.
- [x] 9.3 Perform a full three-game manual series on a phone AVD: game 1, mirrored game 2, no-ban game 3, winner changes, undo, reset, process recreation, and tab switching. Verify: scores, locks, seats, and history remain consistent.
- [x] 9.4 Repeat the manual series on a tablet AVD in portrait and landscape. Verify: two/three-column layouts, team panels, grid spans, and all controls behave correctly.
- [x] 9.5 Verify the 34-character upgrade on a clean AVD and a simulated old-30 install, then verify a custom pool survives the upgrade. Verify: the resulting pool, weights, and rules copy match expectations.
- [x] 9.6 Run `openspec validate "add-android-bo3-draft" --strict` and confirm the change is valid before handoff.

## Workflow follow-up

- Archive or reconcile the completed `add-role-lane-weights` change before archiving this one; its `role-lane-weighting` spec still describes the superseded 30-character preset.
- During archive sync, update the `bo3-global-draft` main-spec Purpose from "native iOS" to cover both native clients, then verify no requirement text remains iOS-only.
- Archive the change only after implementation and manual validation are complete.
- Re-run `openspec validate --specs` after archive sync and confirm both modified capabilities retain all existing iOS scenarios.
