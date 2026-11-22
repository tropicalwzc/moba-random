package com.example.mobarandom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class Bo3DraftEngineTest {
    private fun makePool(count: Int): Bo3Pool {
        val heroes = (1..maxOf(count, 1)).joinToString("、") { "角色$it" }
        return Bo3Pool("测试：$heroes")
    }

    private fun startedSeries(pool: Bo3Pool, noBanGame3: Boolean = true): Bo3Series =
        Bo3DraftEngine.startGame(
            Bo3Series(noBanGame3 = noBanGame3),
            pool,
            Random(7),
        )

    private fun fillActiveGame(series: Bo3Series, heroes: List<String>): Bo3Series {
        var current = series
        heroes.forEach { current = Bo3DraftEngine.choose(current, it, "测试") }
        return current
    }

    private fun completeActiveGame(series: Bo3Series, startingAt: Int, winner: Bo3Team): Bo3Series {
        val heroes = (startingAt until startingAt + 12).map { "角色$it" }
        return Bo3DraftEngine.setWinner(fillActiveGame(series, heroes), winner)
    }

    private fun actionsFor(sequence: List<Bo3Step>, count: Int): List<Bo3Action> =
        sequence.take(count).mapIndexed { index, step ->
            Bo3Action(step.team, step.type, "角色${index + 1}", "测试")
        }

    @Test
    fun defaultSeriesHasThreeEmptyGamesAndNoActiveGame() {
        val series = Bo3Series()
        assertEquals(3, series.games.size)
        assertTrue(series.games.all { !it.started && it.actions.isEmpty() && it.winner == null })
        assertNull(series.activeGame)
        assertEquals(0, series.currentGame)
        assertFalse(series.hasProgress)
    }

    @Test
    fun sequencesMatchTheReference() {
        assertEquals(12, Bo3DraftEngine.stepSequence.size)
        assertEquals(12, Bo3DraftEngine.game2StepSequence.size)
        assertEquals(8, Bo3DraftEngine.game3NoBanSequence.size)
        assertEquals(
            Bo3DraftEngine.stepSequence.filter { it.type == Bo3ActionType.PICK },
            Bo3DraftEngine.game3NoBanSequence,
        )
        assertEquals(
            listOf(
                Bo3Team.A to Bo3ActionType.BAN,
                Bo3Team.B to Bo3ActionType.BAN,
                Bo3Team.A to Bo3ActionType.PICK,
                Bo3Team.B to Bo3ActionType.PICK,
                Bo3Team.B to Bo3ActionType.PICK,
                Bo3Team.A to Bo3ActionType.PICK,
                Bo3Team.A to Bo3ActionType.BAN,
                Bo3Team.B to Bo3ActionType.BAN,
                Bo3Team.B to Bo3ActionType.PICK,
                Bo3Team.A to Bo3ActionType.PICK,
                Bo3Team.A to Bo3ActionType.PICK,
                Bo3Team.B to Bo3ActionType.PICK,
            ),
            Bo3DraftEngine.stepSequence.map { it.team to it.type },
        )
    }

    @Test
    fun game2MirrorsEveryTeamAndPreservesTypes() {
        Bo3DraftEngine.stepSequence.zip(Bo3DraftEngine.game2StepSequence).forEach { (g1, g2) ->
            assertEquals(g1.team.opponent(), g2.team)
            assertEquals(g1.type, g2.type)
        }
    }

    @Test
    fun game3NoBanAndFullSequencesResolveFromTheStartedFlag() {
        var series = Bo3Series(noBanGame3 = true, currentGame = 3)
        series = series.copy(games = series.games.toMutableList().also { it[2] = Bo3Game(started = false, noBan = true) })
        assertTrue(Bo3DraftEngine.usesNoBan(3, series))
        assertEquals(8, Bo3DraftEngine.sequenceForGame(3, series).size)

        series = series.copy(games = series.games.toMutableList().also { it[2] = Bo3Game(started = true, noBan = false) })
        assertFalse(Bo3DraftEngine.usesNoBan(3, series))
        assertEquals(12, Bo3DraftEngine.sequenceForGame(3, series).size)
        assertEquals(12, Bo3DraftEngine.sequenceForGame(1, series).size)
        assertEquals(12, Bo3DraftEngine.sequenceForGame(2, series).size)
        assertEquals(Bo3Availability.Available, Bo3DraftEngine.availability("角色1", series))

        series = series.copy(noBanGame3 = false)
        assertEquals(12, Bo3DraftEngine.sequenceForGame(3, series).size)
    }

    @Test
    fun poolDeduplicatesAcrossCategoriesAndKeepsOrder() {
        val pool = Bo3Pool("射手：A、B、A\n打野：B、C")
        assertEquals(listOf("A", "B"), pool.categories[0].heroes)
        assertEquals(listOf("C"), pool.categories[1].heroes)
        assertEquals(listOf("A", "B"), pool.duplicates)
        assertEquals(3, pool.total)
        assertEquals("打野", pool.role("C"))
        assertTrue(pool.contains("A"))
        assertFalse(pool.contains("D"))
        assertNull(pool.role("D"))
    }

    @Test
    fun availabilityPrefersCurrentGameThenPriorPicksAndReleasesBans() {
        var series = Bo3Series(currentGame = 2)
        series = series.copy(
            games = listOf(
                Bo3Game(
                    started = true,
                    actions = listOf(
                        Bo3Action(Bo3Team.A, Bo3ActionType.BAN, "甘雨", "射手"),
                        Bo3Action(Bo3Team.B, Bo3ActionType.PICK, "温迪", "射手"),
                    ),
                ),
                Bo3Game(
                    started = true,
                    actions = listOf(Bo3Action(Bo3Team.A, Bo3ActionType.BAN, "刻晴", "打野")),
                ),
                Bo3Game(),
            ),
        )
        assertTrue(Bo3DraftEngine.availability("刻晴", series) is Bo3Availability.CurrentGame)
        assertTrue(Bo3DraftEngine.availability("温迪", series) is Bo3Availability.GlobalPick)
        assertEquals(Bo3Availability.Available, Bo3DraftEngine.availability("甘雨", series))
    }

    @Test
    fun lockMessagesExplainTheLockSource() {
        val prior = Bo3Action(Bo3Team.A, Bo3ActionType.PICK, "温迪", "射手")
        val current = Bo3Action(Bo3Team.B, Bo3ActionType.BAN, "甘雨", "射手")
        val series = Bo3Series(teamNames = Bo3TeamNames("红队", "紫队"))
        assertTrue(Bo3DraftEngine.lockMessage(Bo3Availability.CurrentGame(current), series).contains("紫队"))
        assertTrue(Bo3DraftEngine.lockMessage(Bo3Availability.GlobalPick(1, prior), series).contains("红队"))
        assertTrue(Bo3DraftEngine.lockMessage(Bo3Availability.GlobalPick(1, prior), series).contains("第 1 局"))
    }

    @Test
    fun startGameBlocksSmallPoolsAndAcceptsTwelve() {
        val small = makePool(11)
        val error = runCatching { Bo3DraftEngine.startGame(Bo3Series(), small, Random(1)) }.exceptionOrNull()
        assertTrue(error is Bo3EngineException)
        assertEquals(Bo3ErrorKind.POOL_TOO_SMALL, (error as Bo3EngineException).kind)

        val series = startedSeries(makePool(12))
        assertEquals(1, series.currentGame)
        assertTrue(series.games[0].started)
        assertTrue(Bo3DraftEngine.isValidSeats(series.seats))
    }

    @Test
    fun winnerRequiresCompleteDraftAndUndoClearsWinnerBeforeAction() {
        val pool = makePool(30)
        var series = startedSeries(pool)
        series = Bo3DraftEngine.choose(series, "角色1", "测试")
        val early = runCatching { Bo3DraftEngine.setWinner(series, Bo3Team.A) }.exceptionOrNull()
        assertTrue(early is Bo3EngineException)
        assertEquals(Bo3ErrorKind.WINNER_NOT_ALLOWED, (early as Bo3EngineException).kind)

        series = Bo3DraftEngine.setWinner(fillActiveGame(series, (2..12).map { "角色$it" }), Bo3Team.A)
        assertEquals(1, series.winsA)
        series = Bo3DraftEngine.undo(series)!!
        assertNull(series.games[0].winner)
        assertEquals(12, series.games[0].actions.size)
        series = Bo3DraftEngine.undo(series)!!
        assertEquals(11, series.games[0].actions.size)
        assertEquals(Bo3Team.A, series.games[0].actions.last().team)
    }

    @Test
    fun nextGameGatingAndRemovedPicks() {
        val pool = makePool(24)
        var series = startedSeries(pool)
        series = completeActiveGame(series, 1, Bo3Team.A)
        series = Bo3DraftEngine.startGame(series, pool)
        assertEquals(2, series.currentGame)
        series = completeActiveGame(series, 13, Bo3Team.B)
        assertFalse(Bo3DraftEngine.canStartNextGame(series, makePool(18)))

        // Six heroes still in the edited pool were picked; eight were only banned.
        val edited = Bo3Pool(
            "测试：角色1、角色2、角色3、角色4、角色5、角色6、角色7、角色8、角色9、角色10、角色13、角色14、角色19、角色20",
        )
        assertEquals(14, edited.total)
        assertEquals(8, Bo3DraftEngine.remainingPicksAvailable(series, edited))
        assertTrue(Bo3DraftEngine.canStartNextGame(series, edited))
        val game3 = Bo3DraftEngine.startGame(series, edited)
        assertEquals(3, game3.currentGame)
        assertTrue(game3.games[2].noBan)

        val shortError = runCatching {
            Bo3DraftEngine.startGame(series, makePool(18))
        }.exceptionOrNull()
        assertTrue(shortError is Bo3EngineException)
        assertEquals(Bo3ErrorKind.INSUFFICIENT_REMAINING, (shortError as Bo3EngineException).kind)
    }

    @Test
    fun seatsAreAlwaysAValidFourFourSplit() {
        repeat(100) {
            val seats = Bo3DraftEngine.generateSeats()
            assertTrue(Bo3DraftEngine.isValidSeats(seats))
            assertEquals(8, (seats.a + seats.b).toSet().size)
        }
        assertFalse(Bo3DraftEngine.isValidSeats(null))
        assertFalse(Bo3DraftEngine.isValidSeats(Bo3Seats(listOf(1, 1, 2, 3), listOf(4, 5, 6, 7))))
        assertFalse(Bo3DraftEngine.isValidSeats(Bo3Seats(listOf(1, 2, 3), listOf(4, 5, 6, 7))))
    }

    @Test
    fun resetPreservesSettingsAndClearsProgress() {
        var series = startedSeries(makePool(30))
        series = series.copy(teamNames = Bo3TeamNames("红队", "紫队"), noBanGame3 = false)
        series = Bo3DraftEngine.reset(series)
        assertEquals(0, series.currentGame)
        assertNull(series.seats)
        assertTrue(series.games.all { !it.started && it.actions.isEmpty() && it.winner == null })
        assertEquals("红队", series.teamNames.a)
        assertFalse(series.noBanGame3)
    }

    @Test
    fun sanitizeRejectsWrongVersionAndOutOfRangeGame() {
        assertEquals(Bo3Series(), Bo3DraftEngine.sanitize(Bo3Series(version = 99)))
        val repaired = Bo3DraftEngine.sanitize(
            Bo3Series(teamNames = Bo3TeamNames("红队", "紫队"), currentGame = 4, noBanGame3 = false),
        )
        assertEquals(0, repaired.currentGame)
        assertEquals("红队", repaired.teamNames.a)
        assertFalse(repaired.noBanGame3)
    }

    @Test
    fun sanitizeKeepsValidPrefixDropsIncompleteWinnerAndClearsFutureGames() {
        val sequence = Bo3DraftEngine.stepSequence
        val actions = actionsFor(sequence, 12)
        var series = Bo3Series(currentGame = 1)
        series = series.copy(
            games = listOf(
                Bo3Game(started = true, actions = actions.take(1), winner = Bo3Team.A),
                Bo3Game(started = true, actions = actions.take(3)),
                Bo3Game(),
            ),
            seats = Bo3Seats(listOf(1, 1, 2, 3), listOf(4, 5, 6, 7)),
            teamNames = Bo3TeamNames("  红队  ", ""),
        )
        val repaired = Bo3DraftEngine.sanitize(series)
        assertEquals(1, repaired.games[0].actions.size)
        assertNull(repaired.games[0].winner)
        assertFalse(repaired.games[1].started)
        assertTrue(repaired.games[1].actions.isEmpty())
        assertEquals("红队", repaired.teamNames.a)
        assertEquals("B 队", repaired.teamNames.b)
        assertTrue(Bo3DraftEngine.isValidSeats(repaired.seats))
    }

    @Test
    fun sanitizeStopsAtFirstInvalidActionAndKeepsValidGames() {
        val first = actionsFor(Bo3DraftEngine.stepSequence, 12)
        val second = actionsFor(Bo3DraftEngine.game2StepSequence, 12)
        val bad = second.toMutableList()
        bad[3] = bad[3].copy(team = bad[3].team.opponent())
        var series = Bo3Series(currentGame = 2)
        series = series.copy(
            games = listOf(
                Bo3Game(started = true, actions = first, winner = Bo3Team.A),
                Bo3Game(started = true, actions = bad, winner = Bo3Team.B),
                Bo3Game(),
            ),
        )
        val repaired = Bo3DraftEngine.sanitize(series)
        assertEquals(12, repaired.games[0].actions.size)
        assertEquals(3, repaired.games[1].actions.size)
        assertNull(repaired.games[1].winner)
        assertEquals(2, repaired.currentGame)
    }
}
