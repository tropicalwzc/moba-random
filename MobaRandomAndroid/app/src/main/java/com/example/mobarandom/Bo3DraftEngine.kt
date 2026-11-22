package com.example.mobarandom

import kotlin.random.Random

/**
 * Pure BO3 global-BP rules. Mirrors the iOS engine:
 * - game 1 uses the 12-step sequence;
 * - game 2 mirrors every A/B assignment;
 * - game 3 uses the 8-pick sequence only when its started noBan flag (or the
 *   series setting before it starts) is true;
 * - prior picks are globally locked, prior bans are not;
 * - a winner requires a complete active draft.
 */
object Bo3DraftEngine {
    const val MINIMUM_POOL_FOR_GAME = 12
    const val MINIMUM_POOL_FOR_NO_BAN_GAME_3 = 24
    const val MINIMUM_POOL_FOR_FULL_GAME_3 = 28

    val stepSequence: List<Bo3Step> = listOf(
        Bo3Step(Bo3Team.A, Bo3ActionType.BAN),
        Bo3Step(Bo3Team.B, Bo3ActionType.BAN),
        Bo3Step(Bo3Team.A, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.B, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.B, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.A, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.A, Bo3ActionType.BAN),
        Bo3Step(Bo3Team.B, Bo3ActionType.BAN),
        Bo3Step(Bo3Team.B, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.A, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.A, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.B, Bo3ActionType.PICK),
    )

    val game2StepSequence: List<Bo3Step> = stepSequence.map {
        Bo3Step(it.team.opponent(), it.type)
    }

    val game3NoBanSequence: List<Bo3Step> = listOf(
        Bo3Step(Bo3Team.A, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.B, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.B, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.A, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.B, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.A, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.A, Bo3ActionType.PICK),
        Bo3Step(Bo3Team.B, Bo3ActionType.PICK),
    )

    fun usesNoBan(gameNo: Int, series: Bo3Series): Boolean {
        if (gameNo != 3) return false
        val game = series.games.getOrNull(2) ?: return series.noBanGame3
        return if (game.started) game.noBan else series.noBanGame3
    }

    fun sequenceForGame(gameNo: Int, series: Bo3Series): List<Bo3Step> = when {
        gameNo == 2 -> game2StepSequence
        gameNo == 3 && usesNoBan(3, series) -> game3NoBanSequence
        else -> stepSequence
    }

    fun activeSequence(series: Bo3Series): List<Bo3Step> =
        if (series.currentGame == 0) stepSequence else sequenceForGame(series.currentGame, series)

    fun currentStep(series: Bo3Series): Pair<Bo3Step, Int>? {
        val game = series.activeGame ?: return null
        if (!game.started) return null
        val sequence = activeSequence(series)
        if (game.actions.size >= sequence.size) return null
        return sequence[game.actions.size] to game.actions.size
    }

    fun availability(hero: String, series: Bo3Series): Bo3Availability {
        val active = series.activeGame
        active?.actions?.firstOrNull { it.hero == hero }?.let {
            return Bo3Availability.CurrentGame(it)
        }

        val priorCount = maxOf(0, series.currentGame - 1)
        for (index in 0 until minOf(priorCount, series.games.size)) {
            val game = series.games[index]
            if (!game.started) continue
            game.actions.firstOrNull { it.type == Bo3ActionType.PICK && it.hero == hero }?.let {
                return Bo3Availability.GlobalPick(index + 1, it)
            }
        }
        return Bo3Availability.Available
    }

    fun pickedHeroes(series: Bo3Series, throughGameNumber: Int = series.currentGame): Set<String> {
        val upper = minOf(maxOf(throughGameNumber, 0), series.games.size)
        val heroes = mutableSetOf<String>()
        for (index in 0 until upper) {
            series.games[index].actions.forEach {
                if (it.type == Bo3ActionType.PICK) heroes += it.hero
            }
        }
        return heroes
    }

    fun currentGameHeroes(series: Bo3Series): Set<String> =
        series.activeGame?.actions?.map { it.hero }?.toSet().orEmpty()

    /** Only pool heroes that are not globally locked count toward the next game. */
    fun remainingPicksAvailable(series: Bo3Series, pool: Bo3Pool): Int {
        val locked = pickedHeroes(series, series.currentGame)
        return pool.allHeroes.count { it !in locked }
    }

    fun nextGameRequirement(series: Bo3Series): Int =
        sequenceForGame(minOf(3, maxOf(1, series.currentGame + 1)), series).size

    fun canStartNextGame(series: Bo3Series, pool: Bo3Pool): Boolean {
        if (series.currentGame == 0) return pool.total >= MINIMUM_POOL_FOR_GAME
        val game = series.activeGame ?: return false
        if (series.currentGame >= 3 || !game.started) return false
        if (game.actions.size < activeSequence(series).size) return false
        if (game.winner == null || series.isSeriesOver) return false
        return remainingPicksAvailable(series, pool) >= nextGameRequirement(series)
    }

    fun startGame(series: Bo3Series, pool: Bo3Pool, random: Random = Random.Default): Bo3Series {
        if (series.currentGame == 0) {
            if (pool.total < MINIMUM_POOL_FOR_GAME) {
                throw Bo3EngineException(
                    Bo3ErrorKind.POOL_TOO_SMALL,
                    "角色池不足 $MINIMUM_POOL_FOR_GAME 名角色，当前 ${pool.total} 名。请先补充角色池。",
                )
            }
            val games = MutableList(Bo3Series.GAME_COUNT) { Bo3Game() }
            games[0] = Bo3Game(started = true)
            return series.copy(
                games = games,
                seats = generateSeats(random),
                currentGame = 1,
            )
        }

        val game = series.activeGame ?: throw Bo3EngineException(
            Bo3ErrorKind.CANNOT_START_NEXT_GAME,
            "请先完成本局征召并判定胜者。",
        )
        if (series.currentGame > 3) {
            throw Bo3EngineException(Bo3ErrorKind.SERIES_OVER, "系列赛已结束，请使用全局重置开启新的系列赛。")
        }
        if (game.actions.size < activeSequence(series).size) {
            throw Bo3EngineException(Bo3ErrorKind.DRAFT_INCOMPLETE, "请先完成本局征召。")
        }
        if (game.winner == null) {
            throw Bo3EngineException(Bo3ErrorKind.WINNER_REQUIRED, "请先判定本局胜者。")
        }
        if (series.isSeriesOver) {
            throw Bo3EngineException(Bo3ErrorKind.SERIES_OVER, "系列赛已结束，请使用全局重置开启新的系列赛。")
        }
        if (series.currentGame >= 3) {
            throw Bo3EngineException(Bo3ErrorKind.SERIES_OVER, "已完成全部 3 局比赛。")
        }

        val nextGame = series.currentGame + 1
        val nextSequence = sequenceForGame(nextGame, series)
        val remaining = remainingPicksAvailable(series, pool)
        if (remaining < nextSequence.size) {
            throw Bo3EngineException(
                Bo3ErrorKind.INSUFFICIENT_REMAINING,
                "剩余可选角色仅 $remaining 名，不足以下一局的 ${nextSequence.size} 手征召。请扩充角色池，或重置后重新开始。",
            )
        }

        val games = series.games.toMutableList()
        games[nextGame - 1] = Bo3Game(
            started = true,
            noBan = nextGame == 3 && series.noBanGame3,
        )
        return series.copy(currentGame = nextGame, games = games)
    }

    fun choose(series: Bo3Series, hero: String, role: String): Bo3Series {
        val game = series.activeGame
        if (game == null || !game.started) {
            throw Bo3EngineException(Bo3ErrorKind.NO_ACTIVE_GAME, "请先开始一局比赛。")
        }
        val sequence = activeSequence(series)
        if (game.actions.size >= sequence.size) {
            throw Bo3EngineException(Bo3ErrorKind.DRAFT_INCOMPLETE, "请先完成本局征召。")
        }
        val trimmedHero = hero.trim()
        if (trimmedHero.isEmpty()) {
            throw Bo3EngineException(Bo3ErrorKind.EMPTY_HERO, "角色名称不能为空。")
        }
        when (val state = availability(trimmedHero, series)) {
            is Bo3Availability.Available -> Unit
            else -> throw Bo3EngineException(Bo3ErrorKind.HERO_LOCKED, lockMessage(state, series))
        }

        val step = sequence[game.actions.size]
        val updatedGame = game.copy(
            actions = game.actions + Bo3Action(
                team = step.team,
                type = step.type,
                hero = trimmedHero,
                role = role.trim(),
            ),
        )
        val games = series.games.toMutableList()
        games[series.currentGame - 1] = updatedGame
        return series.copy(games = games)
    }

    fun setWinner(series: Bo3Series, team: Bo3Team): Bo3Series {
        val game = series.activeGame
        if (game == null || !game.started) {
            throw Bo3EngineException(Bo3ErrorKind.NO_ACTIVE_GAME, "请先开始一局比赛。")
        }
        if (game.actions.size != activeSequence(series).size) {
            throw Bo3EngineException(Bo3ErrorKind.WINNER_NOT_ALLOWED, "征召完成后才能判定本局胜者。")
        }
        val games = series.games.toMutableList()
        games[series.currentGame - 1] = game.copy(winner = team)
        return series.copy(games = games)
    }

    fun reopenWinner(series: Bo3Series): Bo3Series? {
        val game = series.activeGame ?: return null
        if (!game.started || game.winner == null) return null
        val games = series.games.toMutableList()
        games[series.currentGame - 1] = game.copy(winner = null)
        return series.copy(games = games)
    }

    fun undo(series: Bo3Series): Bo3Series? {
        val game = series.activeGame ?: return null
        if (game.winner != null) {
            val games = series.games.toMutableList()
            games[series.currentGame - 1] = game.copy(winner = null)
            return series.copy(games = games)
        }
        if (game.actions.isEmpty()) return null
        val games = series.games.toMutableList()
        games[series.currentGame - 1] = game.copy(actions = game.actions.dropLast(1))
        return series.copy(games = games)
    }

    fun reset(series: Bo3Series): Bo3Series = series.copy(
        currentGame = 0,
        seats = null,
        games = List(Bo3Series.GAME_COUNT) { Bo3Game() },
    )

    fun generateSeats(random: Random = Random.Default): Bo3Seats {
        val numbers = (1..8).shuffled(random)
        return Bo3Seats(numbers.take(4), numbers.drop(4))
    }

    fun isValidSeats(seats: Bo3Seats?): Boolean {
        if (seats == null || seats.a.size != 4 || seats.b.size != 4) return false
        val all = seats.a + seats.b
        return all.size == 8 && all.toSet().size == 8 && all.all { it in 1..8 }
    }

    fun sanitize(decoded: Bo3Series): Bo3Series {
        if (decoded.version != Bo3Series.CURRENT_VERSION) return Bo3Series()

        val names = normalizedTeamNames(decoded.teamNames)
        if (decoded.currentGame !in 0..3) {
            return Bo3Series(teamNames = names, noBanGame3 = decoded.noBanGame3)
        }

        val games = mutableListOf<Bo3Game>()
        for (index in 0 until Bo3Series.GAME_COUNT) {
            val source = decoded.games.getOrNull(index) ?: Bo3Game()
            val noBan = index == 2 && source.noBan
            val sequence = when {
                index == 1 -> game2StepSequence
                index == 2 && noBan -> game3NoBanSequence
                else -> stepSequence
            }
            val seen = mutableSetOf<String>()
            val actions = mutableListOf<Bo3Action>()
            for ((offset, action) in source.actions.take(sequence.size).withIndex()) {
                val hero = action.hero.trim()
                if (hero.isEmpty() || hero in seen ||
                    action.team != sequence[offset].team ||
                    action.type != sequence[offset].type
                ) {
                    break
                }
                actions += Bo3Action(
                    team = sequence[offset].team,
                    type = sequence[offset].type,
                    hero = hero.take(40),
                    role = action.role.trim().take(20),
                )
                seen += hero
            }
            var game = Bo3Game(started = source.started, actions = actions, noBan = noBan)
            if (actions.size == sequence.size) {
                game = game.copy(winner = source.winner)
            }
            game = game.copy(started = source.started || actions.isNotEmpty())
            games += game
        }

        var series = decoded.copy(teamNames = names, games = games)
        if (series.currentGame > 0) {
            val gamesList = series.games.toMutableList()
            gamesList[series.currentGame - 1] = gamesList[series.currentGame - 1].copy(started = true)
            for (index in series.currentGame until Bo3Series.GAME_COUNT) {
                gamesList[index] = Bo3Game()
            }
            series = series.copy(games = gamesList)
            if (!isValidSeats(series.seats)) {
                series = series.copy(seats = generateSeats())
            }
        } else {
            series = series.copy(
                games = List(Bo3Series.GAME_COUNT) { Bo3Game() },
                seats = null,
            )
        }
        return series
    }

    fun normalizedTeamNames(names: Bo3TeamNames): Bo3TeamNames = Bo3TeamNames(
        a = normalizedName(names.a, "A 队"),
        b = normalizedName(names.b, "B 队"),
    )

    fun lockMessage(state: Bo3Availability, series: Bo3Series): String = when (state) {
        is Bo3Availability.Available -> ""
        is Bo3Availability.CurrentGame -> {
            "该角色本局已被 ${series.teamNames.name(state.action.team)} ${state.action.type.label}，同一局内不可重复选择。"
        }
        is Bo3Availability.GlobalPick -> {
            "该角色已在第 ${state.game} 局被 ${series.teamNames.name(state.action.team)} 选用，全局 BP 锁定。"
        }
    }

    private fun normalizedName(value: String, fallback: String): String {
        val trimmed = value.trim()
        return if (trimmed.isEmpty()) fallback else trimmed.take(16)
    }
}
