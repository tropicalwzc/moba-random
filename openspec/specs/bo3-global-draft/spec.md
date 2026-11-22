# BO3 Global Draft Specification

## Purpose

Defines the native iOS BO3 global-BP draft board: the best-of-three series lifecycle, per-game ban/pick sequences, cross-game pick locking, seat assignment, winner handling, shared-pool availability, persistence, and the draft-board presentation.

## Requirements

### Requirement: Root tab access
The iOS application SHALL expose the existing grouping screen and the BO3 draft board as two top-level tabs.

#### Scenario: Show both tabs
- **WHEN** the application finishes launching
- **THEN** the root tab bar shows a 随机 tab and a BO3 tab, with the 随机 tab selected by default unless a previous selection is restored

#### Scenario: Preserve an in-progress series when switching tabs
- **WHEN** the user switches from the BO3 tab to the 随机 tab and back during an active series
- **THEN** the BO3 board restores the same game, step, actions, seats, and score

#### Scenario: Keep the grouping screen available
- **WHEN** the user opens the 随机 tab
- **THEN** the existing grouping, weight-settings, and history behavior remains available

### Requirement: Series lifecycle
The application SHALL manage a best-of-three series from the first game through a champion or an explicit reset.

#### Scenario: Start game 1
- **WHEN** no series is active and the user starts game 1 with a valid pool
- **THEN** the application creates a new seat assignment, marks game 1 as started, and sets the current game to 1

#### Scenario: Start the next game
- **WHEN** the active game has a winner, the series is not over, and the user starts the next game
- **THEN** the application marks that game as started and makes it the active game

#### Scenario: End the series
- **WHEN** one team reaches two game wins
- **THEN** the application reports that team as the champion, shows the final score, and prevents starting another game

#### Scenario: Reset the series
- **WHEN** the user confirms a global reset
- **THEN** the application clears the current game, games, actions, winners, and seats while preserving the role pool, team names, and game-3 setting

### Requirement: Draft sequence
The application SHALL enforce a 12-step sequence for game 1, a 12-step sequence with mirrored A/B assignments for game 2, and a fixed 8-pick sequence for game 3 when the no-ban rule is active.

#### Scenario: Standard game 1 sequence
- **WHEN** the user drafts in game 1
- **THEN** the steps are A ban, B ban, A pick, B pick, B pick, A pick, A ban, B ban, B pick, A pick, A pick, B pick

#### Scenario: Game 2 mirrored teams
- **WHEN** game 2 starts
- **THEN** every A/B assignment is swapped to B ban, A ban, B pick, A pick, A pick, B pick, B ban, A ban, A pick, B pick, B pick, A pick, while the step types and overall draft shape stay unchanged

#### Scenario: No-ban game 3
- **WHEN** game 3 is active and the no-ban rule applies to that game
- **THEN** the steps are the eight picks from the standard sequence in their original order: A, B, B, A, B, A, A, B

#### Scenario: Game 3 with bans
- **WHEN** game 3 is active and the no-ban rule does not apply
- **THEN** the application uses the game-1 12-step sequence with A's ban first

#### Scenario: Fixed order independent of seats
- **WHEN** the seat assignment changes between series
- **THEN** the draft sequences still follow the same team order and do not depend on seat numbers

### Requirement: Global pick locking
The application SHALL lock every character picked in a previous game for the rest of the series, SHALL NOT lock previous bans, and SHALL prevent any character from appearing twice in the same game.

#### Scenario: Lock a previous pick
- **WHEN** a character was picked in an earlier game of the series
- **THEN** that character is unavailable for both teams for the remainder of the series

#### Scenario: Release a previous ban
- **WHEN** a character was banned but not picked in an earlier game
- **THEN** that character remains available in later games

#### Scenario: Block a duplicate in the current game
- **WHEN** a character has already been banned or picked in the current game
- **THEN** selecting that character again is rejected and does not add an action

#### Scenario: Keep a lock after a pool edit
- **WHEN** a previously picked character is removed from the role pool and later added again
- **THEN** the character remains locked by the original pick record

#### Scenario: Explain a locked selection
- **WHEN** the user selects a locked character
- **THEN** the application explains whether the lock is from the current game or from an earlier game, including the team and action that caused it

### Requirement: Winner judgment and reopening
The application SHALL require a winner after the final draft step of each game and SHALL allow that judgment to be reopened.

#### Scenario: Require a winner
- **WHEN** all steps in the active game are complete
- **THEN** the application asks for the winning team and does not allow the next game to start until a winner is recorded

#### Scenario: Record a winner
- **WHEN** the user selects a winning team after a complete draft
- **THEN** the application records the winner, increments that team's series wins, and updates the score

#### Scenario: Reopen a winner
- **WHEN** the user reopens the recorded winner of the active game
- **THEN** the application clears that winner, decrements the series score, and returns the game to the pending-winner state

#### Scenario: Reject an early winner
- **WHEN** the user tries to record a winner before every draft step is complete
- **THEN** the application rejects the action and keeps the draft active

### Requirement: Undo
The application SHALL undo the most recent change in the active game, clearing a recorded winner before removing a draft action.

#### Scenario: Undo a winner
- **WHEN** the active game has a recorded winner and the user invokes undo
- **THEN** the application clears the winner and keeps all draft actions

#### Scenario: Undo an action
- **WHEN** the active game has no winner and at least one action and the user invokes undo
- **THEN** the application removes the last action and restores the previous step

#### Scenario: Disable undo when empty
- **WHEN** the active game has no actions and no winner
- **THEN** the undo control is disabled

#### Scenario: Do not undo prior games
- **WHEN** the user invokes undo while a later game is active
- **THEN** the application changes only the active game and leaves earlier games unchanged

### Requirement: Seat assignment
The application SHALL assign each team four unique seats from the numbers 1 through 8 when a series starts and SHALL persist those seats for the series.

#### Scenario: Assign seats at series start
- **WHEN** the user starts a new series
- **THEN** the application produces a random 4/4 split containing every number from 1 through 8 exactly once

#### Scenario: Preserve seats across launches
- **WHEN** the application relaunches during a series
- **THEN** both teams display the same seat numbers as before

#### Scenario: Reassign seats on reset
- **WHEN** the user resets the series and starts a new one
- **THEN** the application generates a new 4/4 seat assignment

### Requirement: Start and next-game gating
The application SHALL prevent starting a draft when the shared pool cannot supply the required number of distinct characters.

#### Scenario: Block game 1 with a small pool
- **WHEN** the shared pool contains fewer than 12 distinct characters
- **THEN** the application disables starting game 1 and explains the minimum

#### Scenario: Block a next game with insufficient remaining characters
- **WHEN** the number of distinct characters not locked by earlier picks is smaller than the next game's sequence length
- **THEN** the application refuses to start that game and explains how many additional characters are needed

#### Scenario: Allow a sufficient pool
- **WHEN** the shared pool can supply every required distinct character
- **THEN** the application allows the game to start

### Requirement: Shared role-pool availability
The BO3 tab SHALL derive character categories, role recommendations, and availability from the same locally stored role-pool text used by the 随机 tab.

#### Scenario: Use the shared pool
- **WHEN** the BO3 tab loads
- **THEN** its categories and characters match the current shared role-pool text

#### Scenario: Treat categories as recommendations
- **WHEN** a character belongs to a role category
- **THEN** the user can still select that character during any ban or pick step

#### Scenario: Reflect a pool edit
- **WHEN** the user applies a valid pool edit in the BO3 settings
- **THEN** the 随机 tab reads the same updated pool text

#### Scenario: Keep records after a pool edit
- **WHEN** a character used in the current series is removed from the pool
- **THEN** the recorded action and lineup entry remain visible while the character is absent from the selectable grid

### Requirement: Series score and current-turn header
The BO3 tab SHALL show the series score, current game, seat numbers, and the team and action type of the current step.

#### Scenario: Show the score
- **WHEN** a series is active
- **THEN** the header shows each team's game wins, the current game number, and both seat assignments

#### Scenario: Show the current step
- **WHEN** a draft step is active
- **THEN** the header identifies the acting team, whether the step is a ban or a pick, and the step position within the sequence

#### Scenario: Show the champion state
- **WHEN** the series is over
- **THEN** the header identifies the champion and the final score

### Requirement: Draft timeline
The BO3 tab SHALL show every step in the active game's sequence, highlighting the current step and showing the character recorded for each completed step.

#### Scenario: Show pending steps
- **WHEN** a game has not started or has steps remaining
- **THEN** the timeline shows the full sequence with pending steps visually distinct from completed steps

#### Scenario: Show completed steps
- **WHEN** an action is recorded
- **THEN** the corresponding timeline step shows the character and the step is marked complete

#### Scenario: Show the current step
- **WHEN** a step is active
- **THEN** the timeline highlights exactly that step

#### Scenario: Adapt the timeline layout
- **WHEN** the available width is compact
- **THEN** the timeline may collapse into a horizontally scrollable one-row strip embedded in the current-turn card while preserving sequence order

### Requirement: Team lineup
The BO3 tab SHALL show each team's two bans and four picks for the active game.

#### Scenario: Show empty slots
- **WHEN** the active game has fewer than two bans or four picks for a team
- **THEN** the lineup shows the remaining slots as pending

#### Scenario: Show recorded slots
- **WHEN** a team's ban or pick is recorded
- **THEN** the lineup shows the character in the corresponding slot with the team's color and the action type

#### Scenario: Distinguish ban and pick
- **WHEN** a slot is displayed
- **THEN** the application visually distinguishes banned characters from picked characters

### Requirement: Hero pool grid
The BO3 tab SHALL present the selectable characters as a searchable, role-filterable grid with each character's avatar, name, and recommended role.

#### Scenario: Render a character
- **WHEN** the grid displays a character
- **THEN** it shows the avatar or fallback, the character name, and the recommended role

#### Scenario: Mark a used character
- **WHEN** a character is locked in the current game or by an earlier pick
- **THEN** the grid marks it as used and shows whether the lock is current-game or cross-game

#### Scenario: Select an available character
- **WHEN** the user taps an available character during an active step
- **THEN** the application records that character with the current step's team and action type

#### Scenario: Ignore a selection outside a draft
- **WHEN** the user taps a character while no draft step is active
- **THEN** the application does not record an action and explains why

### Requirement: Hero filtering and search
The BO3 tab SHALL let the user filter the grid by recommended role, search by character name, and hide unavailable characters.

#### Scenario: Filter by role
- **WHEN** the user selects a role filter
- **THEN** the grid shows only characters in that category and the filter shows the category count

#### Scenario: Search by name
- **WHEN** the user enters a search string
- **THEN** the grid shows only characters whose names contain that string, ignoring case for Latin characters

#### Scenario: Hide unavailable characters
- **WHEN** the user enables the availability-only filter
- **THEN** the grid hides every character locked in the current game or by an earlier pick

#### Scenario: Clear filters
- **WHEN** the active filters produce no results and the user clears them
- **THEN** the grid returns to the full pool with no search text and only-available disabled

### Requirement: Series settings
The BO3 tab SHALL let the user edit team names and the game-3 no-ban rule for the series.

#### Scenario: Edit team names
- **WHEN** the user applies non-empty team names
- **THEN** the names replace the defaults in the score header, winner controls, and history

#### Scenario: Fall back for empty names
- **WHEN** the user applies an empty team name
- **THEN** the application uses the default name for that team

#### Scenario: Change the game-3 rule before game 3
- **WHEN** the user changes the no-ban rule before game 3 starts
- **THEN** the next game-3 draft uses the new rule

#### Scenario: Defer a change after game 3 starts
- **WHEN** the user changes the no-ban rule after game 3 has started
- **THEN** the active game 3 keeps its original rule and the change applies to the next series

### Requirement: Shared pool editing and health
The BO3 settings SHALL let the user edit the shared role pool and SHALL report whether the pool can complete the current and remaining games.

#### Scenario: Apply a valid pool
- **WHEN** the user applies a pool with at least 12 distinct characters
- **THEN** the application stores the shared pool text and refreshes the BO3 grid

#### Scenario: Reject an empty or too-small pool
- **WHEN** the user applies a pool with no characters or fewer than 12 distinct characters
- **THEN** the application rejects the edit and keeps the previous shared pool

#### Scenario: Report pool health
- **WHEN** the settings or an empty-state view reports pool health
- **THEN** it states whether the pool supports 12-step games, a no-ban game 3, and a full game 3

#### Scenario: Restore the default pool
- **WHEN** the user chooses to restore the default pool
- **THEN** the draft text becomes the shared 34-character default and is applied only when the user confirms

#### Scenario: Report duplicate characters
- **WHEN** the pool text contains the same character more than once
- **THEN** the application keeps the first occurrence and reports the ignored duplicates

### Requirement: Series history
The BO3 tab SHALL show the bans, picks, and result of every completed game in the current series.

#### Scenario: Show history from game 2
- **WHEN** the series has at least one completed prior game
- **THEN** the history lists each prior game with both teams' bans and picks and the game result

#### Scenario: No history before completion
- **WHEN** no prior game has been completed
- **THEN** the history shows an empty state explaining that prior picks will lock in later games

#### Scenario: Read-only history
- **WHEN** the user views a prior game
- **THEN** the application does not allow editing that game's actions or winner

### Requirement: Rules reference
The BO3 tab SHALL provide a rules reference containing the draft order, global-BP behavior, game-3 rule, position guidance, reset behavior, and avatar attribution.

#### Scenario: Open the rules
- **WHEN** the user opens the rules sheet
- **THEN** it shows the 12-step order, the 8-step no-ban order, the global pick-lock rule, and the per-game ban reset

#### Scenario: Show attribution
- **WHEN** the rules sheet is displayed
- **THEN** it credits the reference character avatar source and states that the app is an unofficial tool

### Requirement: Local persistence
The application SHALL persist the current series locally and restore it after relaunch.

#### Scenario: Save after a change
- **WHEN** the user starts a game, records an action, records or reopens a winner, or starts the next game
- **THEN** the application saves the current series state locally

#### Scenario: Restore after relaunch
- **WHEN** the application launches with a saved series
- **THEN** it restores the current game, actions, winners, seats, team names, and game-3 setting

#### Scenario: Keep the pool separate
- **WHEN** the series state is saved
- **THEN** the shared role-pool text is not duplicated inside the series payload

### Requirement: Defensive state recovery
The application SHALL reject or repair invalid persisted series data without crashing or exposing an inconsistent board.

#### Scenario: Corrupt payload
- **WHEN** the saved series cannot be decoded
- **THEN** the application starts with no active series and keeps the shared pool and settings

#### Scenario: Invalid action prefix
- **WHEN** a saved game contains an action with a missing character, an invalid team or type, or a duplicate character
- **THEN** the application keeps only the valid prefix before the first invalid action

#### Scenario: Incomplete game with a winner
- **WHEN** a saved game records a winner but its action count does not match the active sequence
- **THEN** the application discards that winner

#### Scenario: Out-of-range current game
- **WHEN** the saved current game is outside 0 through 3
- **THEN** the application starts with no active series

#### Scenario: Clear future games
- **WHEN** the saved state contains started or populated games after the current game
- **THEN** the application resets those future games

#### Scenario: Repair seats
- **WHEN** a started series has missing or invalid seats
- **THEN** the application generates a new valid 4/4 assignment

### Requirement: Avatar presentation
The BO3 tab SHALL display bundled character avatars with alias resolution, element accent colors, and a deterministic fallback for characters without a portrait.

#### Scenario: Resolve an alias
- **WHEN** a character name is a documented alias of a bundled official name
- **THEN** the application displays the official character's portrait

#### Scenario: Fall back for an unknown character
- **WHEN** a character has no bundled portrait
- **THEN** the application displays a stable gradient tile with the character's first character and no image error

#### Scenario: Mark a used portrait
- **WHEN** a character is used or locked
- **THEN** the grid visually mutes its portrait while keeping it identifiable

#### Scenario: Element accent
- **WHEN** a bundled portrait has an element
- **THEN** the avatar accent uses that element's color

### Requirement: Adaptive layout
The BO3 board SHALL adapt to iPhone portrait, iPhone landscape, iPad portrait, and iPad landscape widths without losing access to the draft controls.

#### Scenario: iPhone portrait
- **WHEN** the board is displayed at compact width and regular height
- **THEN** it uses a single vertical column with a compact arena header that embeds the timeline strip and shows the game number as a top-right overlay, followed by the lineup and hero grid

#### Scenario: iPhone landscape or iPad portrait
- **WHEN** the board is displayed with limited height or intermediate width
- **THEN** it uses a two-column arrangement that keeps the draft controls and hero grid visible

#### Scenario: iPad landscape
- **WHEN** the board is displayed at regular width and compact height
- **THEN** it uses a three-column arrangement with one team panel on each side and the arena and hero grid in the center

#### Scenario: Preserve functionality at every size
- **WHEN** the layout changes
- **THEN** every draft action, filter, settings control, and rules entry point remains reachable
