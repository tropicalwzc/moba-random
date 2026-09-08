## ADDED Requirements

### Requirement: Dynamic weight settings page
The application SHALL provide a dedicated lane-weight settings page whose lanes and characters are derived from the currently parsed role-pool text.

#### Scenario: Open settings from the grouping page
- **WHEN** the user activates the lane-weight settings control on the grouping page
- **THEN** the application opens a separate page containing one editable weight for every current character/lane pair

#### Scenario: Adapt to custom lanes and characters
- **WHEN** the role-pool text contains user-defined lane and character names
- **THEN** the settings page displays those names in the parser's stable order without relying on built-in lane names

#### Scenario: Deduplicate a character listed under multiple lanes
- **WHEN** the same exact character name occurs under more than one lane
- **THEN** the settings page displays one character entry and treats its first-listed lane as its default lane

### Requirement: Default and reconciled weight configuration
The application SHALL maintain a valid local weight vector for each current character and SHALL reconcile it when the role pool changes.

#### Scenario: Initialize a character
- **WHEN** a character has no saved weight configuration
- **THEN** the application assigns weight 100 to its first-listed lane and weight 0 to every other current lane

#### Scenario: Add a lane
- **WHEN** a new lane is added while a character already has valid saved weights
- **THEN** the application preserves the existing weights and assigns weight 0 to the new lane

#### Scenario: Remove a lane with assigned weight
- **WHEN** a lane is removed and a current character had positive weight in that lane
- **THEN** the application transfers the removed weight to that character's current first-listed lane and preserves weights for all other surviving lanes

#### Scenario: Add and remove characters
- **WHEN** role-pool editing adds a character and removes another character
- **THEN** the application creates a default vector for the new character and removes the obsolete character's stored vector

#### Scenario: Re-scan when settings opens
- **WHEN** the user edits the role-pool text and then activates the lane-weight settings control
- **THEN** the application parses that current text before constructing the settings page

#### Scenario: Character moves to another lane
- **WHEN** a known character's first-listed lane differs from the source lane recorded with its saved weights
- **THEN** the application discards that character's prior vector and assigns 100 to the new first-listed lane and 0 to every other current lane

#### Scenario: Character remains in its lane
- **WHEN** a known character's recorded source lane still matches its current first-listed lane
- **THEN** the application preserves its valid customized vector while reconciling lane additions and removals

#### Scenario: Migrate weights without source-lane metadata
- **WHEN** a valid legacy character vector has no recorded source lane
- **THEN** the application preserves it and records the current first-listed lane for future move detection

#### Scenario: Recover invalid persisted data
- **WHEN** a saved vector is corrupt, contains a negative or non-integer value, or cannot be reconciled to a total of 100
- **THEN** the application replaces that character's vector with its current one-hot default

#### Scenario: Preserve valid configuration locally
- **WHEN** the user saves valid weights and later reopens the application with the same role pool
- **THEN** the application restores the saved weights without changing them

### Requirement: Integer total validation
The application SHALL accept only non-negative integer lane weights and SHALL persist a character's weights only when their total is exactly 100.

#### Scenario: Total below 100
- **WHEN** a character's draft weights total less than 100
- **THEN** the page shows the remaining amount and prevents the incomplete configuration from being saved

#### Scenario: Non-integer or negative input
- **WHEN** the user enters a non-integer or negative value
- **THEN** the application marks or rejects that input and does not persist the invalid vector

#### Scenario: Leave with an invalid draft
- **WHEN** the user attempts to leave the page while any edited vector does not total 100
- **THEN** the application offers to continue editing or discard the invalid draft instead of applying it to generation

### Requirement: Proportional normalization above 100
The application SHALL automatically normalize a committed character weight vector whose total exceeds 100 into non-negative integers totaling exactly 100 while preserving the entered proportions as closely as possible.

#### Scenario: Normalize two nonzero lanes
- **WHEN** the user commits weights `[90, 20, 0, 0]`
- **THEN** the application replaces them with `[82, 18, 0, 0]`

#### Scenario: Normalize a single value above 100
- **WHEN** the user commits weights `[120, 0, 0, 0]`
- **THEN** the application replaces them with `[100, 0, 0, 0]`

#### Scenario: Allocate integer rounding remainder
- **WHEN** proportional scaling produces fractional shares
- **THEN** the application floors every share and distributes remaining points by descending fractional remainder with ties resolved by lane order

#### Scenario: Do not normalize while typing
- **WHEN** the user has typed a partial numeric value but has not committed the field edit
- **THEN** the application retains the draft text without proportionally modifying the row

#### Scenario: Preserve a total at or below 100
- **WHEN** the user commits a vector whose total is at most 100
- **THEN** the application preserves the entered integer values unchanged

### Requirement: Lane-weighted grouping
The grouping engine SHALL use positive configured lane weights as relative selection weights for complete team/lane assignments.

#### Scenario: Include a multi-lane character
- **WHEN** character A has weights 80 for shooter, 20 for mid, and 0 for every other lane
- **THEN** A participates in shooter selection with base weight 0.8, in mid selection with base weight 0.2, and is absent from all zero-weight lane candidate sets

#### Scenario: Compare shooter weights
- **WHEN** A has shooter weight 80 and B has shooter weight 100 with otherwise identical conditions
- **THEN** A contributes 0.8 and B contributes 1.0 to each eligible shooter-slot weighted choice

#### Scenario: Compose previous-game avoidance
- **WHEN** A has lane weight 80, appeared in the immediately preceding generated result, and automatic previous-round avoidance is enabled
- **THEN** A's effective weight for that lane is `0.8 * 0.1`

#### Scenario: Preserve deterministic seeded results
- **WHEN** two clients generate with equivalent parsed data, saved weights, modes, previous-round set, and seed
- **THEN** they produce the same assignment and player shuffle

#### Scenario: Reject an impossible assignment
- **WHEN** positive weights and uniqueness rules cannot fill every required team/lane slot
- **THEN** generation stops and explains that the current weight configuration cannot form a complete non-duplicated lineup

### Requirement: Character uniqueness across weighted lanes
The grouping engine SHALL prevent a character eligible for multiple lanes from occupying conflicting result slots.

#### Scenario: Normal mode global uniqueness
- **WHEN** mirror mode is disabled and a character has positive weight in multiple lanes
- **THEN** that character appears at most once across both teams and all lanes

#### Scenario: Mirror mode per-team uniqueness
- **WHEN** mirror mode is enabled and a character has positive weight in multiple lanes
- **THEN** that character appears at most once in each team but may appear once in each of the two teams

### Requirement: Weighted manual replacement
The application SHALL apply lane eligibility, configured weights, previous-game avoidance, and active uniqueness rules when replacing a result character.

#### Scenario: Exclude zero-weight and conflicting characters
- **WHEN** the user requests replacement for a lane
- **THEN** the candidate set excludes zero-weight characters, the current character, and all characters prohibited by the active uniqueness mode

#### Scenario: Weight eligible replacement candidates
- **WHEN** more than one valid replacement candidate remains
- **THEN** the application selects among them using configured lane weight multiplied by the previous-game avoidance factor

#### Scenario: No valid replacement
- **WHEN** no valid replacement candidate remains
- **THEN** the application keeps the result unchanged and points the user to role-pool, mirror-mode, or weight settings as applicable

### Requirement: Automatic previous-round avoidance option
The application SHALL offer an option that automatically lowers the effective weight of characters from the immediately preceding generated result without requiring manual character entry.

#### Scenario: Manual field is replaced by a switch
- **WHEN** the grouping rules are displayed
- **THEN** the application shows an automatic previous-round avoidance switch and does not show a free-form previous-game character field

#### Scenario: Enabled after a successful result
- **WHEN** avoidance is enabled and the user successfully generates a new result after an existing result
- **THEN** every character from the existing result receives the `0.1` multiplier while the new result is generated

#### Scenario: Disabled option
- **WHEN** avoidance is disabled
- **THEN** the next generation applies no previous-round multiplier

#### Scenario: Initial generation
- **WHEN** the application generates before any result exists in the current session
- **THEN** no character receives the previous-round multiplier

#### Scenario: Failed generation
- **WHEN** generation fails validation or cannot form an assignment
- **THEN** the application keeps the visible result and previous-round snapshot unchanged

#### Scenario: Replacement after generation
- **WHEN** avoidance is enabled and the user manually replaces a character after generating a new result
- **THEN** replacement selection applies the multiplier to the snapshot used for that generation

### Requirement: Local compatibility and cross-client parity
The iOS, Android, and standalone web clients SHALL implement equivalent observable weight behavior without requiring network access.

#### Scenario: Upgrade without saved weights
- **WHEN** an existing installation first launches a version containing lane weights
- **THEN** the application derives one-hot defaults that preserve the previous role-pool selection behavior

#### Scenario: Preserve history
- **WHEN** weights are added, edited, or reconciled
- **THEN** previously saved history entries remain readable and unchanged

#### Scenario: Use local versioned storage
- **WHEN** a valid weight configuration is saved
- **THEN** the client stores it locally under a versioned weight setting independently of role-pool and history data

### Requirement: iPad weight editor layout
The iOS application SHALL adapt the weight editor to use the available iPad width efficiently.

#### Scenario: Landscape iPad
- **WHEN** the weight settings page is displayed at landscape iPad width
- **THEN** it displays three character cards in each grid row when space permits

#### Scenario: Compact width
- **WHEN** the weight settings page is displayed at compact iPhone width
- **THEN** it displays a single readable character card per row

### Requirement: iOS clipboard weight transfer
The iOS application SHALL export and import valid lane-weight JSON through the system clipboard.

#### Scenario: Export current weights
- **WHEN** the user activates export while every draft row is valid
- **THEN** the application writes versioned JSON containing ordered lanes and all character weights to the clipboard

#### Scenario: Reject invalid import
- **WHEN** clipboard JSON is malformed, contains duplicate or empty names, contains negative or non-integer weights, or any character total is not 100
- **THEN** the application keeps the current draft and homepage role pool unchanged and explains that the JSON cannot be imported

#### Scenario: Import and refresh displays
- **WHEN** valid weight JSON is imported
- **THEN** the settings draft, persisted weights, and homepage role-pool text immediately reflect the imported data

#### Scenario: Derive homepage lane ownership
- **WHEN** imported character A has shooter weight 80 and mid weight 20
- **THEN** the homepage lists A under shooter because it is A's highest-weight lane

#### Scenario: Canonical homepage formatting
- **WHEN** the homepage role-pool text is rebuilt from imported JSON
- **THEN** each line uses `职业：角色A、角色B、角色C` formatting with a full-width colon and ideographic-comma separators

### Requirement: One-time iOS bundled weight preset
The iOS application SHALL apply the supplied bundled weight JSON once for the corresponding application upgrade.

#### Scenario: First launch without the migration marker
- **WHEN** the new application version launches and its bundled-preset migration marker is absent
- **THEN** the application validates and persists the bundled weights, derives the canonical homepage role-pool text, records the marker, and generates from that imported configuration

#### Scenario: Subsequent launch
- **WHEN** the bundled-preset migration marker is already present
- **THEN** the application preserves the user's current role pool and weights without applying the bundled preset again

#### Scenario: Preset cannot be loaded
- **WHEN** the bundled resource is missing or fails weight validation
- **THEN** the application does not record the migration marker and continues using the existing valid local configuration
