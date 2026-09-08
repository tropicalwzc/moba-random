## Why

The current grouping engine treats every character listed under a lane as equally suitable for that lane, so it cannot represent characters that can play multiple lanes with different preferences. A dedicated weight editor is needed so users can distribute each character's lane suitability while preserving a simple, valid total of 100.

## What Changes

- Add a dedicated lane-weight settings page that derives its character rows and lane columns from the current role-pool text.
- Initialize each character with weight 100 for its listed lane and 0 for every other lane, while persisting later custom values locally.
- Accept only non-negative integer weights whose per-character total is 100.
- When an edit makes a character's total exceed 100, automatically scale all weights in that row to a total of 100 using the current proportions and deterministic integer rounding.
- Use each character's configured lane weight in generation and same-lane replacement; zero-weight characters are ineligible for that lane.
- Compose configured weights with the existing previous-game avoidance factor.
- Replace manual previous-game character entry with an optional switch that automatically uses the immediately preceding generated lineup.
- Prevent a multi-lane character from occupying more than one slot in a team, and preserve the existing mirror-mode distinction between cross-team uniqueness and cross-team reuse.
- Re-scan the current role-pool input whenever weight settings are opened, reconcile additions/removals, and reset a character to one-hot defaults when its first-listed lane has changed.
- Keep iOS, Android, and the standalone web version behaviorally aligned.
- Optimize the iPad weight editor into a multi-card grid and add iOS clipboard JSON import/export that can rebuild the homepage role-pool display from each character's highest-weight lane.
- Bundle the supplied iOS weight preset and apply it once after upgrading to the new version, including its derived homepage role pool, without overwriting later user changes on subsequent launches.

## Capabilities

### New Capabilities

- `role-lane-weighting`: Dynamic lane-weight editing, validation, persistence, reconciliation, and weighted conflict-free grouping across the iOS, Android, and web clients.

### Modified Capabilities

None.

## Impact

- Grouping engines and engine tests in the Swift, Kotlin, and JavaScript implementations.
- Main-screen navigation and new dedicated weight-settings UI on all three clients.
- Local persistence gains a versioned role-weight payload; existing role-pool and history data remain compatible.
- Replacement candidate selection changes from original-list membership to positive configured lane weight.
- No network service or new third-party dependency is required.
