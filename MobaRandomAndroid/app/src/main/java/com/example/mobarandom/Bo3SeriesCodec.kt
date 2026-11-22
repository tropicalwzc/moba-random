package com.example.mobarandom

import org.json.JSONArray
import org.json.JSONObject

object Bo3SeriesCodec {
    fun encode(series: Bo3Series): String {
        val root = JSONObject()
            .put("version", series.version)
            .put("teamNames", JSONObject()
                .put("a", series.teamNames.a)
                .put("b", series.teamNames.b))
            .put("noBanGame3", series.noBanGame3)
            .put("currentGame", series.currentGame)
            .put("games", JSONArray().apply {
                series.games.forEach { game ->
                    put(JSONObject().apply {
                        put("started", game.started)
                        put("noBan", game.noBan)
                        game.winner?.let { put("winner", it.name.lowercase()) }
                        put("actions", JSONArray().apply {
                            game.actions.forEach { action ->
                                put(JSONObject()
                                    .put("team", action.team.name.lowercase())
                                    .put("type", action.type.name.lowercase())
                                    .put("hero", action.hero)
                                    .put("role", action.role))
                            }
                        })
                    })
                }
            })
        series.seats?.let {
            root.put("seats", JSONObject()
                .put("a", JSONArray(it.a))
                .put("b", JSONArray(it.b)))
        }
        return root.toString()
    }

    fun decode(raw: String): Bo3Series? = runCatching {
        val root = JSONObject(raw)
        val names = root.optJSONObject("teamNames")
        val gamesArray = root.optJSONArray("games")
        val games = if (gamesArray == null) {
            List(Bo3Series.GAME_COUNT) { Bo3Game() }
        } else {
            List(Bo3Series.GAME_COUNT) { index ->
                val value = gamesArray.optJSONObject(index)
                if (value == null) {
                    Bo3Game()
                } else {
                    val actionsArray = value.optJSONArray("actions")
                    val actions = if (actionsArray == null) emptyList() else {
                        List(actionsArray.length()) { actionIndex ->
                            val action = actionsArray.getJSONObject(actionIndex)
                            Bo3Action(
                                team = team(action.optString("team")),
                                type = type(action.optString("type")),
                                hero = action.optString("hero"),
                                role = action.optString("role"),
                            )
                        }
                    }
                    Bo3Game(
                        started = value.optBoolean("started", false),
                        actions = actions,
                        winner = value.optString("winner").takeIf { it.isNotBlank() }?.let(::team),
                        noBan = value.optBoolean("noBan", false),
                    )
                }
            }
        }
        val seatsObject = root.optJSONObject("seats")
        Bo3Series(
            version = root.optInt("version", Bo3Series.CURRENT_VERSION),
            teamNames = Bo3TeamNames(
                a = names?.optString("a") ?: "A 队",
                b = names?.optString("b") ?: "B 队",
            ),
            noBanGame3 = root.optBoolean("noBanGame3", true),
            seats = seatsObject?.let {
                Bo3Seats(
                    a = it.optJSONArray("a").intList(),
                    b = it.optJSONArray("b").intList(),
                )
            },
            currentGame = root.optInt("currentGame", 0),
            games = games,
        )
    }.getOrNull()

    private fun JSONArray?.intList(): List<Int> {
        if (this == null) return emptyList()
        return List(length()) { index -> optInt(index) }
    }

    private fun team(value: String): Bo3Team = when (value.lowercase()) {
        "b" -> Bo3Team.B
        else -> Bo3Team.A
    }

    private fun type(value: String): Bo3ActionType = when (value.lowercase()) {
        "pick" -> Bo3ActionType.PICK
        else -> Bo3ActionType.BAN
    }
}
