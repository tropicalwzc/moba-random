# Proposal

## Why

The iOS app already has a complete BO3 global-BP draft board, but Android users still only have the grouping tool. This creates a feature gap for the same product and forces Android users to use the HTML reference or lose the draft workflow. Android also still ships the older 30-character default pool, so the two native clients show different rosters and the shared rules copy would be inaccurate on Android.

## What Changes

- Add a BO3 tab to the Android app alongside the existing grouping screen, using a bottom navigation bar consistent with the iOS two-tab shell.
- Port the complete BO3 rules engine to Kotlin: game 1 and game 2 sequences, full A/B mirroring in game 2, no-ban game 3, cross-game pick locking, per-game ban reset, seat assignment, winner judgment and reopening, undo, next-game gating, series reset, and defensive state recovery.
- Build the Android BO3 board with the same regions as iOS: score and current-turn header, timeline, two-team lineup strip or tablet side panels, role/search/availability filters, hero grid, settings, rules, and history.
- Reuse the existing bundled BO3 avatars and alias index, loading them from Android assets with element accents and a deterministic fallback.
- Persist the series locally and sanitize it on restore, keeping the shared role-pool text outside the series payload.
- Infer phone/tablet layouts from the global screen size: one compact column on phone portrait, two columns at intermediate width, and three columns on large landscape screens.
- Upgrade the Android shared default role pool and bundled weight preset from 30 to the iOS 34-character roster.
- Align the Android one-time preset migration with iOS: fresh installs and known built-in defaults upgrade to 34, while custom pools and weights from pre-marker upgrades are preserved.
- Keep the existing Android grouping UI and behavior intact except for the intentional 34-character default-roster change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bo3-global-draft`: Generalize root tab access and adaptive layout from iOS-only to iOS and Android, and add Android bottom-navigation, phone/tablet layout, avatar asset, and persistence scenarios.
- `role-pool-defaults`: Extend the shared role-pool contract to Android, apply the 34-character default roster and preset migration to Android, and add Android preservation and upgrade scenarios.

## Impact

- Android `GroupingEngine`, role-pool default text, bundled weight preset, and preset migration policy.
- New Android BO3 models, draft engine, series store, avatar repository, board views, adapters, and activities/dialogs.
- Android assets: `app/src/main/assets/BO3/avatar-index.json` and the bundled WebP portraits.
- Android manifest, theme/color resources, strings, bottom navigation, and layout resources.
- Android unit tests for the draft engine, default roster, preset migration, and layout-mode resolution.
- No network service, account system, or new third-party runtime dependency is required.
- iOS implementation remains behaviorally unchanged; only shared capability specifications are generalized.
- Coordination: the completed but unarchived `add-role-lane-weights` change still names the old 30-character preset; archive or reconcile it before archiving this change.
