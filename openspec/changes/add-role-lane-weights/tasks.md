## 1. Shared Behavior Fixtures

- [x] 1.1 Define cross-client fixture cases for one-hot defaults, duplicate-name ownership, role-pool reconciliation, and invalid stored payload recovery
- [x] 1.2 Define golden normalization cases, including `90/20 -> 82/18`, values above 100, fractional-remainder ties, totals below 100, and invalid numeric input
- [x] 1.3 Define fixed-seed weighted assignment fixtures covering 80/20 eligibility, previous-game decay, normal-mode global uniqueness, mirror-mode per-team uniqueness, and impossible configurations

## 2. iOS Weight Model and Engine

- [x] 2.1 Add Codable versioned character/lane weight models plus default generation, validation, largest-remainder normalization, and role-pool reconciliation
- [x] 2.2 Extend the Swift grouping engine to consume effective lane weights and produce seeded conflict-free complete assignments with explicit impossible-configuration errors
- [x] 2.3 Update Swift replacement selection to enforce positive lane weight, configured weighting, previous-game decay, and active uniqueness rules
- [x] 2.4 Add Swift unit tests for the shared model, normalization, migration, weighted generation, deterministic seeds, uniqueness, replacement, and backward-compatible history behavior

## 3. iOS Weight Settings UI

- [x] 3.1 Add versioned local weight persistence and a navigation entry from the grouping page to a dedicated SwiftUI settings page
- [x] 3.2 Build an adaptive character/lane weight editor with integer fields, page-local drafts, live totals, incomplete-state feedback, and commit-time proportional normalization
- [x] 3.3 Prevent saving incomplete vectors, handle invalid-draft navigation with continue/discard choices, and connect saved values to generation and replacement
- [x] 3.4 Update iOS hints and error messages for weighted lanes, normalization, uniqueness conflicts, and unavailable replacements

## 4. Android Weight Support

- [x] 4.1 Add equivalent versioned Kotlin weight models, SharedPreferences JSON persistence, validation, normalization, and role-pool reconciliation
- [x] 4.2 Port constrained seeded weighted generation and weighted replacement behavior to the Kotlin engine
- [x] 4.3 Add a dedicated Android weight settings destination with adaptive integer editing, draft totals, commit-time normalization, save gating, and invalid-draft navigation handling
- [x] 4.4 Add Kotlin unit tests using the shared fixtures and update Android strings and accessibility descriptions

## 5. Web Weight Support

- [x] 5.1 Add equivalent versioned JavaScript weight models, localStorage persistence, validation, normalization, and role-pool reconciliation
- [x] 5.2 Port constrained seeded weighted generation and weighted replacement eligibility to the standalone web engine
- [x] 5.3 Add a dedicated responsive web weight-settings view with integer draft editing, totals, commit-time normalization, save gating, and discard handling
- [x] 5.4 Add executable JavaScript behavior checks using the shared fixtures and update web hints and errors

## 6. Cross-Platform Verification

- [x] 6.1 Run iOS unit tests and build the iPhone/iPad application, fixing any regressions without overwriting pre-existing unrelated workspace changes
- [x] 6.2 Run Android unit tests and debug build, fixing any regressions without overwriting pre-existing Gradle configuration changes
- [x] 6.3 Exercise the standalone web flow for pool edits, weight persistence, over-100 normalization, weighted generation, replacement, and reload behavior
- [x] 6.4 Compare all golden fixed-seed outputs across Swift, Kotlin, and JavaScript and update README behavior documentation

## 7. Automatic Previous-Round Avoidance

- [x] 7.1 Replace the iOS manual previous-game field with a switch and snapshot the prior successful result for generation and replacement
- [x] 7.2 Replace the Android manual previous-game field with a switch and snapshot the prior successful result for generation and replacement
- [x] 7.3 Replace the web manual previous-game field with a switch and snapshot the prior successful result for generation and replacement
- [x] 7.4 Add state-transition tests, update documentation, and rerun all cross-platform validation

## 8. Role-Pool Position Rescan

- [x] 8.1 Record source-lane metadata and reset moved characters during Swift reconciliation and settings opening
- [x] 8.2 Implement equivalent source-lane persistence and moved-character reset on Android
- [x] 8.3 Implement equivalent source-lane persistence and moved-character reset on web
- [x] 8.4 Add cross-platform movement and legacy-migration tests, update fixtures/docs, and rerun validation

## 9. iPad Layout and Clipboard Transfer

- [x] 9.1 Replace the iOS weight-page vertical list with an adaptive grid that fits three character cards per row on landscape iPad
- [x] 9.2 Add validated ordered-lane JSON export and backward-compatible clipboard import
- [x] 9.3 Rebuild and persist canonical homepage role-pool text from imported highest-weight lanes and refresh the open editor immediately
- [x] 9.4 Add import/export, validation, ownership, formatting, and empty-lane tests; update documentation and rerun iOS/OpenSpec validation

## 10. One-Time Built-In iOS Preset

- [x] 10.1 Add the supplied validated weight JSON as a bundled iOS resource
- [x] 10.2 Apply the preset before initial generation when a preset-specific migration marker is absent
- [x] 10.3 Persist the derived homepage role pool and weights, and prevent repeat application after success
- [x] 10.4 Add preset integrity and one-time migration tests, update documentation, and rerun iOS/OpenSpec validation
