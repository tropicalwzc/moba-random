package com.example.mobarandom

import android.content.Context
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject

object RoleWeightStorage {
    const val PREFERENCES_NAME = "moba_random_preferences"
    const val KEY_ROLE_WEIGHTS = "moba_role_weights_v1"

    fun load(context: Context, poolText: String): RoleWeightConfiguration {
        val categories = GroupingEngine.parseRolePool(poolText)
        val raw = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ROLE_WEIGHTS, null)
        val saved = raw?.let(::decode)
        return RoleWeightConfiguration.reconcile(categories, saved).also { save(context, it) }
    }

    fun save(context: Context, configuration: RoleWeightConfiguration) {
        val characters = JSONArray()
        configuration.characters.forEach { entry ->
            val weights = JSONObject()
            entry.laneWeights.forEach { (lane, value) -> weights.put(lane, value) }
            val item = JSONObject().put("character", entry.character).put("laneWeights", weights)
            entry.sourceLane?.let { item.put("sourceLane", it) }
            characters.put(item)
        }
        val payload = JSONObject()
            .put("version", configuration.version)
            .put("characters", characters)
            .toString()
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE).edit {
            putString(KEY_ROLE_WEIGHTS, payload)
        }
    }

    private fun decode(raw: String): RoleWeightConfiguration? = runCatching {
        val root = JSONObject(raw)
        val array = root.getJSONArray("characters")
        val entries = buildList {
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                val weightsObject = item.getJSONObject("laneWeights")
                val weights = linkedMapOf<String, Int>()
                weightsObject.keys().forEach { lane -> weights[lane] = weightsObject.getInt(lane) }
                add(CharacterLaneWeights(
                    character = item.getString("character"),
                    laneWeights = weights,
                    sourceLane = item.optString("sourceLane", "").takeIf(String::isNotEmpty),
                ))
            }
        }
        RoleWeightConfiguration(root.getInt("version"), entries)
    }.getOrNull()
}
