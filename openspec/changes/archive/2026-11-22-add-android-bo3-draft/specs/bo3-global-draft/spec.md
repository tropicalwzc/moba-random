# Spec Delta

## MODIFIED Requirements

### Requirement: Root tab access
The iOS and Android applications SHALL expose the existing grouping screen and the BO3 draft board as two top-level tabs.

#### Scenario: Show both tabs
- **WHEN** the application finishes launching
- **THEN** the root tab bar shows a 随机 tab and a BO3 tab, with the 随机 tab selected by default unless a previous selection is restored

#### Scenario: Preserve an in-progress series when switching tabs
- **WHEN** the user switches from the BO3 tab to the 随机 tab and back during an active series
- **THEN** the BO3 board restores the same game, step, actions, seats, and score

#### Scenario: Keep the grouping screen available
- **WHEN** the user opens the 随机 tab
- **THEN** the existing grouping, weight-settings, and history behavior remains available

#### Scenario: Show Android tabs
- **WHEN** the Android application finishes launching
- **THEN** the root shows a bottom navigation bar with a 随机 item and a BO3 item

#### Scenario: Restore the Android tab selection
- **WHEN** the Android application relaunches after the user selected the BO3 tab
- **THEN** the BO3 tab is restored unless the user explicitly returns to 随机

### Requirement: Adaptive layout
The BO3 board SHALL adapt to iOS phone and tablet sizes and Android phone and tablet sizes without losing access to the draft controls.

#### Scenario: iPhone portrait
- **WHEN** the board is displayed at compact width and regular height
- **THEN** it uses a single vertical column with a compact arena header that embeds the timeline strip and shows the game number as a top-right overlay, followed by the lineup and hero grid

#### Scenario: iPhone landscape or iPad portrait
- **WHEN** the board is displayed with limited height or intermediate width
- **THEN** it uses a two-column arrangement that keeps the draft controls and hero grid visible

#### Scenario: iPad landscape
- **WHEN** the board is displayed at regular width and compact height
- **THEN** it uses a three-column arrangement with one team panel on each side and the arena and hero grid in the center

#### Scenario: Android phone portrait
- **WHEN** the Android board is displayed below 600 dp of width
- **THEN** it uses a single compact column with the header, embedded timeline, lineup, filters, and scrollable hero grid

#### Scenario: Android two-column layout
- **WHEN** the Android board is displayed with at least 600 dp of width but does not meet the three-column condition
- **THEN** it uses a two-column arrangement that keeps the draft controls beside the hero grid

#### Scenario: Android tablet landscape
- **WHEN** the Android board is displayed with at least 900 dp of width and at least 600 dp of height
- **THEN** it uses a three-column arrangement with one team panel on each side and the arena and hero grid in the center

#### Scenario: Preserve functionality at every size
- **WHEN** the layout changes
- **THEN** every draft action, filter, settings control, and rules entry point remains reachable
