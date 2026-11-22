package com.example.mobarandom

import android.graphics.Color
import kotlin.math.abs

object Bo3Palette {
    const val TEAM_A = 0xFFD93F4B.toInt()
    const val TEAM_B = 0xFF7C4DFF.toInt()
    const val TEAM_A_CONTAINER = 0xFFFFE8EA.toInt()
    const val TEAM_B_CONTAINER = 0xFFEFE8FF.toInt()
    const val GOLD = 0xFF9A6B16.toInt()
    const val GOLD_CONTAINER = 0xFFFFF6DF.toInt()

    private val roleColors = mapOf(
        "射手" to 0xFFF2C86B.toInt(),
        "打野" to 0xFF4ADE80.toInt(),
        "中路" to 0xFFA78BFA.toInt(),
        "战士" to 0xFFFB7185.toInt(),
        "辅助" to 0xFF38BDF8.toInt(),
        "坦克" to 0xFFFBBF24.toInt(),
    )

    private val extraRoleColors = intArrayOf(
        0xFF38BDF8.toInt(),
        0xFFF472B6.toInt(),
        0xFFFBBF24.toInt(),
        0xFF34D399.toInt(),
        0xFFA78BFA.toInt(),
        0xFFFB923C.toInt(),
        0xFF60A5FA.toInt(),
        0xFFE879F9.toInt(),
        0xFF2DD4BF.toInt(),
        0xFFF87171.toInt(),
    )

    private val elementColors = mapOf(
        "风" to 0xFF7AD7B5.toInt(),
        "火" to 0xFFFF8B6B.toInt(),
        "水" to 0xFF59B9FF.toInt(),
        "冰" to 0xFFA9E8FF.toInt(),
        "雷" to 0xFFC6A3FF.toInt(),
        "岩" to 0xFFF0C96F.toInt(),
        "草" to 0xFF93DC72.toInt(),
    )

    fun team(team: Bo3Team): Int = if (team == Bo3Team.A) TEAM_A else TEAM_B
    fun teamContainer(team: Bo3Team): Int = if (team == Bo3Team.A) TEAM_A_CONTAINER else TEAM_B_CONTAINER

    fun role(role: String): Int = roleColors[role]
        ?: extraRoleColors[(hash(role).toUInt() % extraRoleColors.size.toUInt()).toInt()]

    fun element(element: String?): Int? = element?.let { elementColors[it] }

    fun hash(value: String): Int {
        var hash = 0
        value.forEach { character ->
            hash = hash * 31 + character.code
        }
        return hash
    }

    fun fallbackColors(seed: Int): Pair<Int, Int> {
        val first = (abs(seed) % 360) / 360f
        val second = ((abs(seed) + 38) % 360) / 360f
        return Color.HSVToColor(floatArrayOf(first, 0.58f, 0.44f)) to
            Color.HSVToColor(floatArrayOf(second, 0.62f, 0.24f))
    }
}
