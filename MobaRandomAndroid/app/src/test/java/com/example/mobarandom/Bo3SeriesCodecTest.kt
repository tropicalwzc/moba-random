package com.example.mobarandom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Bo3SeriesCodecTest {
    @Test
    fun roundTripPreservesSeriesState() {
        val series = Bo3Series(
            teamNames = Bo3TeamNames("红队", "紫队"),
            noBanGame3 = false,
            seats = Bo3Seats(listOf(1, 2, 3, 4), listOf(5, 6, 7, 8)),
            currentGame = 2,
            games = listOf(
                Bo3Game(
                    started = true,
                    actions = listOf(Bo3Action(Bo3Team.A, Bo3ActionType.PICK, "温迪", "射手")),
                    winner = Bo3Team.A,
                ),
                Bo3Game(started = true, noBan = false),
                Bo3Game(),
            ),
        )

        val decoded = Bo3SeriesCodec.decode(Bo3SeriesCodec.encode(series))

        assertEquals(series, decoded)
    }

    @Test
    fun corruptPayloadReturnsNull() {
        assertNull(Bo3SeriesCodec.decode("{not-json"))
        assertNull(Bo3SeriesCodec.decode(""))
    }

    @Test
    fun seriesPayloadDoesNotContainTheSharedPool() {
        val payload = Bo3SeriesCodec.encode(Bo3Series())
        assertFalse(payload.contains("温迪"))
        assertFalse(payload.contains("moba_role_pool"))
        assertFalse(payload.contains("射手："))
    }

    @Test
    fun invalidVersionIsRejectedBySanitize() {
        val decoded = Bo3SeriesCodec.decode(Bo3SeriesCodec.encode(Bo3Series(version = 99)))
        assertEquals(Bo3Series(), Bo3DraftEngine.sanitize(decoded!!))
    }

    @Test
    fun sanitizeClearsFutureGamesAfterDecode() {
        var series = Bo3Series(currentGame = 1)
        series = series.copy(
            games = listOf(
                Bo3Game(started = true),
                Bo3Game(started = true),
                Bo3Game(),
            ),
        )
        val sanitized = Bo3DraftEngine.sanitize(Bo3SeriesCodec.decode(Bo3SeriesCodec.encode(series))!!)
        assertEquals(1, sanitized.currentGame)
        assertTrue(sanitized.games[0].started)
        assertFalse(sanitized.games[1].started)
        assertTrue(sanitized.games[1].actions.isEmpty())
    }
}
