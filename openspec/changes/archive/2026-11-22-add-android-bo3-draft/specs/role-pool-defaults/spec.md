# Spec Delta

## MODIFIED Requirements

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
