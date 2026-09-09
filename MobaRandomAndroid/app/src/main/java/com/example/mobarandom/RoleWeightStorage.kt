package com.example.mobarandom

import android.content.Context
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject

object RoleWeightStorage {
    const val PREFERENCES_NAME = "moba_random_preferences"
    const val KEY_ROLE_WEIGHTS = "moba_role_weights_v1"
    const val KEY_ROLE_POOL = "moba_role_pool"
    private const val KEY_BUILT_IN_PRESET_V2_APPLIED = "moba_builtin_weight_preset_v2_applied"

    fun load(context: Context, poolText: String): RoleWeightConfiguration {
        val categories = GroupingEngine.parseRolePool(poolText)
        val raw = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ROLE_WEIGHTS, null)
        val saved = raw?.let(::decode)
        return RoleWeightConfiguration.reconcile(categories, saved).also { save(context, it) }
    }

    fun save(context: Context, configuration: RoleWeightConfiguration) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE).edit {
            putString(KEY_ROLE_WEIGHTS, encode(configuration))
        }
    }

    fun saveImported(context: Context, imported: ImportedRoleWeights) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE).edit {
            putString(KEY_ROLE_POOL, imported.poolText)
            putString(KEY_ROLE_WEIGHTS, encode(imported.configuration))
        }
    }

    fun applyBuiltInPresetIfNeeded(context: Context): Boolean {
        val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        if (preferences.getBoolean(KEY_BUILT_IN_PRESET_V2_APPLIED, false)) return false
        val currentPool = preferences.getString(KEY_ROLE_POOL, GroupingEngine.DEFAULT_POOL_TEXT).orEmpty()
        val currentLanes = GroupingEngine.parseRolePool(currentPool).map { it.name }
        val imported = runCatching {
            val json = context.resources.openRawResource(R.raw.default_role_weights_v2)
                .bufferedReader()
                .use { it.readText() }
            RoleWeightTransfer.importJson(json, currentLanes)
        }.getOrNull() ?: return false
        return preferences.edit()
            .putString(KEY_ROLE_POOL, imported.poolText)
            .putString(KEY_ROLE_WEIGHTS, encode(imported.configuration))
            .putBoolean(KEY_BUILT_IN_PRESET_V2_APPLIED, true)
            .commit()
    }

    internal fun encode(configuration: RoleWeightConfiguration): String {
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
        return payload.toString()
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

data class ImportedRoleWeights(
    val lanes: List<String>,
    val poolText: String,
    val configuration: RoleWeightConfiguration,
)

class RoleWeightTransferException(message: String) : IllegalArgumentException(message)

object RoleWeightTransfer {
    fun exportJson(lanes: List<String>, configuration: RoleWeightConfiguration): String {
        val characters = validate(lanes, configuration.characters)
            ?: throw RoleWeightTransferException("当前权重不是有效的 100 整数配置。")
        return JSONObject()
            .put("version", configuration.version)
            .put("lanes", JSONArray(lanes))
            .put("characters", JSONArray().apply {
                characters.forEach { entry ->
                    val item = JSONObject()
                        .put("character", entry.character)
                        .put("laneWeights", JSONObject().apply {
                            lanes.forEach { lane -> put(lane, entry.laneWeights[lane] ?: 0) }
                        })
                    entry.sourceLane?.let { item.put("sourceLane", it) }
                    put(item)
                }
            })
            .toString(2)
    }

    fun importJson(json: String, currentLanes: List<String>): ImportedRoleWeights {
        val root = runCatching { JSONObject(json) }.getOrElse {
            throw RoleWeightTransferException("剪贴板中没有可识别的权重 JSON。")
        }
        val versionValue = root.opt("version")
        if ((versionValue !is Int && versionValue !is Long) ||
            (versionValue as Number).toLong() != RoleWeightConfiguration.CURRENT_VERSION.toLong()
        ) invalidConfiguration()
        val characters = decodeCharacters(root)
        val lanes = if (root.has("lanes")) {
            val array = root.optJSONArray("lanes") ?: invalidConfiguration()
            List(array.length()) { index ->
                (array.get(index) as? String) ?: invalidConfiguration()
            }
        } else {
            val importedKeys = characters.flatMap { it.laneWeights.keys }.toSet()
            val current = currentLanes.filter { it in importedKeys }
            current + (importedKeys - current.toSet()).sorted()
        }
        return validatedImport(lanes, characters)
    }

    internal fun validatedImport(
        lanes: List<String>,
        characters: List<CharacterLaneWeights>,
    ): ImportedRoleWeights {
        val validated = validate(lanes, characters) ?: invalidConfiguration()
        return deriveHomepagePool(lanes, validated)
    }

    internal fun deriveHomepagePool(
        lanes: List<String>,
        characters: List<CharacterLaneWeights>,
    ): ImportedRoleWeights {
        val grouped = lanes.associateWithTo(linkedMapOf()) { mutableListOf<String>() }
        val canonical = characters.map { entry ->
            val primaryLane = lanes.withIndex().maxWithOrNull(
                compareBy<IndexedValue<String>> { entry.laneWeights[it.value] ?: 0 }
                    .thenBy { -it.index }
            )?.value ?: invalidConfiguration()
            grouped.getValue(primaryLane).add(entry.character)
            CharacterLaneWeights(entry.character, entry.laneWeights, primaryLane)
        }
        val poolText = lanes.joinToString("\n") { lane ->
            "$lane：${grouped.getValue(lane).joinToString("、")}"
        }
        return ImportedRoleWeights(lanes, poolText, RoleWeightConfiguration(characters = canonical))
    }

    private fun decodeCharacters(root: JSONObject): List<CharacterLaneWeights> {
        val array = root.optJSONArray("characters") ?: invalidConfiguration()
        return List(array.length()) { index ->
            val item = array.optJSONObject(index) ?: invalidConfiguration()
            val character = item.opt("character") as? String ?: invalidConfiguration()
            val weightObject = item.optJSONObject("laneWeights") ?: invalidConfiguration()
            val weights = linkedMapOf<String, Int>()
            weightObject.keys().forEach { lane ->
                val value = weightObject.get(lane)
                if (value !is Int && value !is Long) invalidConfiguration()
                val longValue = (value as Number).toLong()
                if (longValue !in 0..Int.MAX_VALUE.toLong()) invalidConfiguration()
                weights[lane] = longValue.toInt()
            }
            CharacterLaneWeights(
                character = character,
                laneWeights = weights,
                sourceLane = when (val sourceLane = item.opt("sourceLane")) {
                    null, JSONObject.NULL -> null
                    is String -> sourceLane.takeIf(String::isNotEmpty)
                    else -> invalidConfiguration()
                },
            )
        }
    }

    private fun validate(
        lanes: List<String>,
        characters: List<CharacterLaneWeights>,
    ): List<CharacterLaneWeights>? {
        if (lanes.isEmpty() || lanes.any { it.isBlank() } || lanes.distinct().size != lanes.size) return null
        if (characters.isEmpty() || characters.any { it.character.isBlank() } ||
            characters.map { it.character }.distinct().size != characters.size
        ) return null
        val laneSet = lanes.toSet()
        return characters.map { entry ->
            if (entry.laneWeights.keys.any { it !in laneSet } || entry.laneWeights.values.any { it < 0 }) return null
            val weights = lanes.associateWithTo(linkedMapOf()) { entry.laneWeights[it] ?: 0 }
            if (weights.values.sumOf(Int::toLong) != 100L) return null
            CharacterLaneWeights(entry.character, weights, entry.sourceLane)
        }
    }

    private fun invalidConfiguration(): Nothing = throw RoleWeightTransferException(
        "JSON 中的分路和角色名称必须唯一且非空，每个角色只能使用非负整数，权重合计必须为 100。"
    )
}
