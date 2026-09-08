## Context

The three clients parse editable text into an ordered list of lane categories, then independently select characters from each category. The character-specific previous-game penalty is enabled from the grouping rules and is derived automatically from the immediately preceding generated result. Because the input lists are normally disjoint, the existing engine only enforces uniqueness between the two teams inside one lane; multi-lane weights make duplicate characters across different lanes a normal possibility and therefore require assignment-level conflict handling.

Weights and role-pool data remain device-local. Character and lane names are user-authored strings, so they are the only stable identifiers available across launches.

## Goals / Non-Goals

**Goals:**

- Provide a dedicated, dynamic editor for one integer weight per character/lane pair.
- Keep every saved character vector valid with a total of exactly 100.
- Make over-allocation pleasant by proportionally normalizing totals above 100.
- Apply the same seeded weighting and uniqueness semantics on iOS, Android, and web.
- Reconcile saved values predictably after role-pool edits without changing historical results.
- Let users enable previous-round avoidance without transcribing character names.

**Non-Goals:**

- Synchronizing settings between devices or platforms.
- Supporting decimals, negative weights, fixed built-in lane names, or a fixed character count.
- Promising that a value such as 80 is an absolute 80% outcome frequency. It is a relative lane weight and is also affected by competing characters, previous-game avoidance, and uniqueness constraints.
- Rewriting or reinterpreting saved game history after weights change.

## Decisions

### Derive a canonical dynamic matrix from the role-pool text

Parsing continues to preserve lane order. Characters are deduplicated by exact display name in first-seen order, and the first lane containing a duplicated name is its default lane. A default vector is one-hot: 100 for that lane and 0 for all other lanes. This produces a valid total even if a user listed the same character on multiple lines; cross-lane suitability is represented by the weight matrix thereafter.

The shared conceptual model is:

```
RoleWeightConfiguration(version, characters)
CharacterWeights(characterName, sourceLane, laneWeights: laneName -> Int)
```

Each client stores equivalent versioned JSON under its local preferences mechanism. Names are keys because the source format has no IDs.

Alternative considered: embed weights into the role-pool text. This was rejected because it makes the compact pool syntax harder to edit and conflicts with the requirement for a dedicated settings page.

### Keep an editable draft and save only valid vectors

The settings page is a separate navigation destination. It displays characters as rows (or cards on narrow screens), the current lanes as fields, and a live total/remaining indicator. Fields accept decimal digits representing non-negative integers.

Edits remain in page-local draft state. A row whose total is below 100 is visibly incomplete, and the page cannot persist while any row is incomplete. Navigating away with invalid edits asks the user to continue editing or discard the draft. This avoids exposing a partially edited configuration to generation.

### Normalize over-allocation with the largest-remainder method

Normalization occurs when a field edit is committed (for example submit, focus loss, or equivalent platform action), rather than on each keystroke. Let the non-negative integer values after the edit be `v[0...n]` and `S = sum(v)`.

- If `S <= 100`, preserve the entered values.
- If `S > 100`, calculate each exact share as `v[i] * 100 / S`.
- Assign each lane `floor(exactShare)`.
- Distribute the remaining points one at a time to the largest fractional remainders, breaking ties by the current lane order.

This guarantees non-negative integers totaling exactly 100 while preserving the current proportions as closely as integer values allow. For example, `[90, 20, 0, 0]` becomes `[82, 18, 0, 0]`; `[120, 0, 0, 0]` becomes `[100, 0, 0, 0]`.

Alternative considered: cap only the edited field at the remaining allowance. That is simpler but discards the proportions the user just expressed.

### Reconcile saved settings against role-pool edits

Every time the settings are loaded for a parsed pool:

- Re-parse the current, unsaved-in-the-editor role-pool text when the user opens weight settings rather than relying on an earlier parsed snapshot.
- Add new characters with their one-hot default vector.
- Remove stored characters no longer present.
- Record each character's current first-listed lane as `sourceLane`; if a saved non-null `sourceLane` differs from the current first-listed lane, reset the entire character vector to the new one-hot default before displaying the editor.
- For legacy entries without `sourceLane`, preserve the valid vector once and attach the current first-listed lane so subsequent moves are detected without discarding existing customization during migration.
- Add new lanes to existing vectors with weight 0.
- Remove obsolete lanes and transfer their combined weight to the character's current first-listed default lane, preserving all weights on lanes that still exist.
- Reset a character to its one-hot default if persisted JSON is corrupt, contains negative/non-integer values, or still does not total 100 after reconciliation.
- Treat a rename as removal of the old name and addition of a new character.

Reconciliation is persisted only as a valid versioned configuration. This conserves customized active-lane weights for unchanged characters while ensuring moving a character in the source list cannot leave an invisible positive weight on its old lane.

### Sample complete valid assignments, not isolated lane picks

For a character `c` and lane `l`, the effective generation weight is:

```
effective(c, l) = configuredInteger(c, l) / 100
                  * (previousGameContains(c) ? 0.1 : 1.0)
```

Zero configured weight means no candidate edge. The engine builds all required team/lane slots and uses the seeded random generator with weighted candidate ordering plus backtracking. It selects the most constrained remaining slot first and backtracks when a choice would make the rest of the assignment impossible. Stable lane/character order resolves ties so the same configuration and seed produce the same result on all clients.

In normal mode, one character may occur at most once across both teams. In mirror mode, the two teams are solved independently: a character may occur once on each team but never occupy two lanes on the same team. If no complete assignment exists, generation reports a weight-configuration error instead of silently violating weights or uniqueness.

Sequential constrained sampling does not promise exact global marginal probabilities under conflicts. It does preserve configured relative preference at each candidate choice and avoids the combinatorial cost of enumerating every complete matching.

### Apply eligibility and weights to manual replacement

Replacement uses characters with positive weight for the selected lane, excluding the current character and every character forbidden by the active uniqueness mode. It uses configured lane weight multiplied by the same previous-game factor. If there is no eligible candidate, the existing unavailable-replacement feedback is shown with wording that points to the weight settings.

### Derive previous-round avoidance from generated state

The grouping rules expose an off-by-default switch instead of a free-form previous-game text field. Immediately before replacing the current generated result, each client snapshots all A/B characters from that result as the previous-round set. If the switch is enabled, this snapshot receives the `0.1` multiplier during the new generation and subsequent manual replacements; if disabled, the engine receives an empty set. Initial generation has no preceding result and therefore applies no penalty. Failed generation keeps both the visible result and the prior snapshot unchanged.

The switch remains session-local, matching the existing mirror-mode switch. Historical entries remain presentation data and are not implicitly selected as the prior round after a fresh launch.

### Preserve cross-client seeded behavior and local compatibility

Swift, Kotlin, and JavaScript use equivalent normalization, reconciliation, effective-weight, tie-breaking, and constrained-assignment rules. Existing role-pool and history keys remain readable. A new versioned key is used for weights, so rollback simply causes older builds to ignore the additional data.

### Provide an iPad grid and clipboard transfer format

The iOS weight page uses an adaptive card grid with a minimum card width sized so a landscape iPad displays three character cards per row while compact iPhone widths remain single-column. Horizontal scrolling remains inside each character card when its lane fields exceed the available card width.

The iOS client exports a UTF-8 JSON payload containing `version`, ordered `lanes`, and the character weight entries. Import validates non-empty unique lane and character names, non-negative integer weights, and an exact total of 100 per character. Legacy configuration JSON without an explicit `lanes` array is also accepted by using the current page's lane order followed by any additional weight keys in stable sorted order.

After a successful import, each character is assigned to its highest-weight lane for the homepage role-pool text; ties use imported lane order. The generated text uses one line per lane and the canonical `职业：角色A、角色B` punctuation. Imported character weights are preserved, their `sourceLane` is updated to the derived primary lane, and both the settings page and homepage update immediately.

### Apply the supplied preset once on iOS upgrade

The supplied transfer payload is bundled as an application JSON resource. Before the initial automatic grouping on launch, iOS checks a preset-specific `UserDefaults` migration flag. If the flag is absent, it loads and validates the bundled payload through the same import path used by clipboard import, persists the imported configuration, rebuilds the homepage role-pool text from highest-weight lanes, and only then records the flag and generates the initial result.

The flag is written only after a successful import. It is never cleared by ordinary role-pool edits, weight edits, clipboard imports, or later launches, so the built-in preset cannot overwrite subsequent user customization. A future intentionally different preset must use a new migration identifier.

## Risks / Trade-offs

- [Name-based identity loses customization when a character or lane is renamed] -> Treat rename as remove/add and make that behavior explicit; the text format offers no durable identifier.
- [Backtracking can become expensive for pathological large or highly constrained pools] -> Choose the most constrained slot first, prune zero-weight and already-used candidates, and stop immediately after a valid assignment is found.
- [Constrained assignment changes marginal probabilities] -> Describe values as relative weights and test deterministic choice behavior rather than claiming an absolute observed percentage.
- [Three implementations can drift] -> Use shared golden fixtures for parsing, normalization, reconciliation, effective weights, fixed seeds, and failure cases.
- [Editing many characters on a phone can be dense] -> Use per-character cards or an adaptive grid, keep the total visible, and provide clear invalid-state feedback.

## Migration Plan

1. Add the versioned model and reconciliation logic; absence of saved weights yields one-hot defaults matching current behavior.
2. Add engine support and tests while retaining existing history decoding.
3. Add the dedicated editor and navigation on each client.
4. Update replacement behavior and user-facing hints.
5. Run native unit/build tests and browser interaction checks with common fixtures.

Rollback requires only reverting the new code. Existing builds ignore the additional local-storage key, and historical entries require no migration.

## Open Questions

None. The proposal adopts first-listed ownership for duplicate source names, commit-time proportional normalization, and global/per-team uniqueness as the cross-platform defaults.
