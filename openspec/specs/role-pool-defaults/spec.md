# Role Pool Defaults Specification

## Purpose

Defines the shared role-pool default roster and the one-time bundled-preset behavior that keep the grouping and BO3 modes on the same character data without overwriting upgraded users.

## Requirements

### Requirement: Shared role-pool storage
The iOS and Android applications SHALL use one locally stored role-pool text per installation as the source of truth for both the grouping and BO3 modes.

#### Scenario: Edit from either mode
- **WHEN** the user applies a valid role-pool edit in either mode
- **THEN** the other mode reads the same updated text

#### Scenario: Derive both modes from one text
- **WHEN** either mode parses the pool
- **THEN** it sees the same categories and character names in the same order

#### Scenario: Keep the pool outside series state
- **WHEN** BO3 series state is saved
- **THEN** the role-pool text is stored separately and is not cleared by a series reset

#### Scenario: Edit from either Android mode
- **WHEN** the user applies a valid role-pool edit in either Android mode
- **THEN** the other Android mode reads the same updated text after it becomes visible

### Requirement: Default 34-character roster
The application SHALL use the reference 34-character roster as the default role pool for fresh installations and explicit restores.

#### Scenario: Fresh installation default
- **WHEN** the application has no stored role pool and no bundled preset has been applied
- **THEN** the effective default pool contains 34 distinct characters in the reference categories: 7 shooter, 6 jungle, 8 mid, and 13 warrior

#### Scenario: Reference roster content
- **WHEN** the default pool is applied
- **THEN** it contains the reference names, including 赛索斯, 杜林, 法尔加, 克洛林德, and 赛诺, and uses 八重 rather than 神子

#### Scenario: Reference lane placement
- **WHEN** the default pool is applied
- **THEN** 魈 is listed under jungle and 琴 under mid, matching the reference roster

#### Scenario: Restore default
- **WHEN** the user explicitly restores the default pool
- **THEN** the stored pool becomes the 34-character roster

#### Scenario: Preserve an existing pool
- **WHEN** an upgraded installation already has a stored pool that differs from every known built-in default
- **THEN** the application does not replace it with the 34-character roster

### Requirement: One-time bundled preset update
The application SHALL ship a bundled weight preset matching the 34-character default roster and SHALL apply it at most once per installation to fresh installations and to installations whose stored pool is a known built-in default, without overwriting a custom pool or its weights.

#### Scenario: Apply on a fresh installation
- **WHEN** the application launches without the bundled-preset marker and without a stored role pool
- **THEN** it validates the 34-character preset, persists its weights and derived pool text, records the marker, and uses that configuration for generation

#### Scenario: Upgrade a known built-in pool
- **WHEN** the application launches without the bundled-preset marker and the stored pool equals a known built-in default
- **THEN** it applies the 34-character preset, records the marker, and replaces that built-in pool

#### Scenario: Preserve a pre-marker custom pool
- **WHEN** the application launches without the bundled-preset marker and the stored pool differs from every known built-in default
- **THEN** it keeps the stored pool and weights, records the migration as handled, and does not replace them with the preset

#### Scenario: Preserve an upgraded installation
- **WHEN** the bundled-preset marker is already present
- **THEN** the application keeps the user's current pool and weights and does not apply the preset again

#### Scenario: Preserve user edits
- **WHEN** the user has edited the pool or weights after the preset was applied
- **THEN** a later launch does not restore the preset content

#### Scenario: Handle an invalid preset
- **WHEN** the bundled preset is missing or fails validation
- **THEN** the application does not record the marker and continues with the current valid configuration or the default pool

#### Scenario: Upgrade an Android legacy default
- **WHEN** the Android application launches without the bundled-preset marker and its stored pool is the previous 30-character default
- **THEN** it applies the 34-character preset and records the marker

#### Scenario: Preserve an Android pre-marker custom pool
- **WHEN** the Android application launches without the bundled-preset marker and its stored pool is custom
- **THEN** it keeps the custom pool and weights and records the migration as handled

### Requirement: Preset readiness before either mode renders
The application SHALL complete the one-time preset migration before the grouping or BO3 tab reads the shared role pool.

#### Scenario: Launch into the BO3 tab
- **WHEN** the application restores a previous BO3 tab selection on first launch after the upgrade
- **THEN** the shared pool has already been initialized from the preset or the default before the BO3 board loads

#### Scenario: Launch into the 随机 tab
- **WHEN** the application opens the 随机 tab on first launch after the upgrade
- **THEN** the same initialized pool is available to grouping

#### Scenario: Migration failure
- **WHEN** the preset cannot be applied
- **THEN** the application still opens either tab with a valid default or stored pool

### Requirement: Preset-compatible weight reconciliation
The application SHALL keep the grouping weight configuration valid after the default roster changes.

#### Scenario: Add new characters
- **WHEN** the 34-character preset introduces characters without saved weights
- **THEN** each new character receives weight 100 in its first-listed lane and 0 in every other lane

#### Scenario: Move a character
- **WHEN** the preset or default changes a character's first-listed lane
- **THEN** that character's saved vector resets to the new one-hot default

#### Scenario: Preserve unchanged characters
- **WHEN** a character keeps its first-listed lane and has a valid saved vector
- **THEN** the application preserves its weights

#### Scenario: Generate from the 34-character pool
- **WHEN** the user generates a grouping from the default 34-character pool
- **THEN** the engine produces a complete assignment using the valid weight configuration
