package com.example.mobarandom

enum class Bo3Team(val sideLabel: String, val shortLabel: String) {
    A("红方", "A"),
    B("紫方", "B");

    fun opponent(): Bo3Team = if (this == A) B else A
}

enum class Bo3ActionType(val label: String, val shortLabel: String) {
    BAN("禁用", "禁"),
    PICK("选用", "选"),
}

data class Bo3Step(val team: Bo3Team, val type: Bo3ActionType)

data class Bo3Action(
    val team: Bo3Team,
    val type: Bo3ActionType,
    val hero: String,
    val role: String,
)

data class Bo3Game(
    val started: Boolean = false,
    val actions: List<Bo3Action> = emptyList(),
    val winner: Bo3Team? = null,
    val noBan: Boolean = false,
)

data class Bo3Seats(val a: List<Int>, val b: List<Int>) {
    fun forTeam(team: Bo3Team): List<Int> = if (team == Bo3Team.A) a else b
}

data class Bo3TeamNames(
    val a: String = "A 队",
    val b: String = "B 队",
) {
    fun name(team: Bo3Team): String = if (team == Bo3Team.A) a else b
}

data class Bo3Series(
    val version: Int = CURRENT_VERSION,
    val teamNames: Bo3TeamNames = Bo3TeamNames(),
    val noBanGame3: Boolean = true,
    val seats: Bo3Seats? = null,
    val currentGame: Int = 0,
    val games: List<Bo3Game> = List(GAME_COUNT) { Bo3Game() },
) {
    companion object {
        const val CURRENT_VERSION = 1
        const val GAME_COUNT = 3
    }

    val activeGame: Bo3Game?
        get() = if (currentGame in 1..GAME_COUNT) games.getOrNull(currentGame - 1) else null

    val winsA: Int
        get() = games.count { it.winner == Bo3Team.A }

    val winsB: Int
        get() = games.count { it.winner == Bo3Team.B }

    val isSeriesOver: Boolean
        get() = winsA >= 2 || winsB >= 2

    val champion: Bo3Team?
        get() = when {
            winsA >= 2 -> Bo3Team.A
            winsB >= 2 -> Bo3Team.B
            else -> null
        }

    val hasProgress: Boolean
        get() = currentGame > 0 || games.any { it.started || it.actions.isNotEmpty() || it.winner != null }
}

sealed class Bo3Availability {
    object Available : Bo3Availability()
    data class CurrentGame(val action: Bo3Action) : Bo3Availability()
    data class GlobalPick(val game: Int, val action: Bo3Action) : Bo3Availability()

    val isAvailable: Boolean
        get() = this is Available
}

enum class Bo3ErrorKind {
    POOL_TOO_SMALL,
    INSUFFICIENT_REMAINING,
    NO_ACTIVE_GAME,
    DRAFT_INCOMPLETE,
    WINNER_REQUIRED,
    SERIES_OVER,
    HERO_LOCKED,
    EMPTY_HERO,
    WINNER_NOT_ALLOWED,
    NOTHING_TO_UNDO,
    CANNOT_START_NEXT_GAME,
}

class Bo3EngineException(
    val kind: Bo3ErrorKind,
    override val message: String,
) : Exception(message)
