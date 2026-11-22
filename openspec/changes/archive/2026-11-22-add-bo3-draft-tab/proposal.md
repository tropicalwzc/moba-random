## Why

The app currently supports one-off grouping only. The reference BO3 draft page provides a complete global-BP series workflow, but it lives as a separate, desktop-oriented HTML file outside the native app. Users want the same tournament draft flow on iOS, using the app's existing role pool and the reference character avatars, without switching to a browser.

## What Changes

- Add a root tab bar with the existing grouping screen and a new native BO3 draft tab.
- Implement the BO3 series state machine: a 12-step draft for game 1, a 12-step game 2 with mirrored A/B assignments, an optional 8-pick no-ban game 3, per-game bans, global locking of prior picks, best-of-three scoring, winner judgment and reopening, undo, and series reset.
- Add the draft board UI: a dark arena header with score and current turn, a 12/8-step timeline, a two-team ban/pick lineup, role filters, search, availability filtering, and used/global-locked hero badges.
- Bundle the 131 character avatars from the reference HTML as 96x96 WebP resources with ASCII ids, an alias/element index, and a gradient-initial fallback for unknown or missing portraits.
- Extend the shared role-pool default to the reference 34-character roster (7 shooter / 6 jungle / 8 mid / 13 warrior) and update the bundled weight-preset payload to the same roster. Retain the existing one-time migration marker so upgrades with custom pools keep their current pool and weights, while known built-in defaults are upgraded.
- Move the one-time bundled-preset migration to app launch so the shared pool is ready before either tab renders.
- Add BO3 settings (team names, shared pool editor, game-3 no-ban rule, pool health) and a rules sheet containing the reference rule copy and avatar attribution.
- Persist the series locally with defensive load sanitization, and keep the role pool shared with the grouping tab.
- Add engine, persistence, parser, and avatar-catalog tests.
- App changes are iOS-only. The reference BO3 HTML receives the same game-2 ban rule as a separate follow-up; the grouping web page, Android, and HTML state import remain out of scope.

## Capabilities

### New Capabilities
- `bo3-global-draft`: Native BO3 series draft-board behavior, including draft sequences, global pick locking, per-game bans, seats, winner flow, shared-pool availability, persistence, and avatar presentation.
- `role-pool-defaults`: Shared default role-pool roster and one-time bundled-preset behavior for fresh installs and restores, without overwriting upgraded users.

### Modified Capabilities
None.

## Impact

- iOS app: a new `Features/BO3` module and a root tab view; the existing grouping view remains the first tab.
- Shared role-pool default text and bundled preset resource; grouping default parsing, fixed-seed, and preset migration test expectations.
- New avatar resources and a generated index; the app bundle grows by roughly 335 KB before compression.
- The existing `add-role-lane-weights` change is complete but not archived; its 30-character preset requirement is superseded for fresh installs by the new shared default, while the v2 marker is deliberately retained so upgraded installations are not overwritten.
- Android and the grouping web page are unchanged. The reference BO3 HTML receives the game-2 ban sync separately.
- No network service or third-party runtime dependency is added.
