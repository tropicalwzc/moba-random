package com.example.mobarandom

data class RoleCategory(val name: String, val roles: List<String>)

data class GroupingResult(
    val seed: Long,
    val playersA: List<Int>,
    val playersB: List<Int>,
    val rolesA: List<String>,
    val rolesB: List<String>,
) {
    val formattedText: String
        get() = """
            Group A
            ${playersA.joinToString("，")}
            ${rolesA.joinToString("，")}

            Group B
            ${playersB.joinToString("，")}
            ${rolesB.joinToString("，")}
        """.trimIndent()
}

sealed class GroupingException(message: String) : IllegalArgumentException(message) {
    class InvalidPool : GroupingException(
        "角色池格式不正确或为空。请确保每行格式为：职业名：角色1、角色2"
    )

    class InsufficientRoles(category: String) : GroupingException(
        "职业“$category”的角色数量不足 2 个。请补充角色，或开启“允许两组使用相同角色”。"
    )
}

object GroupingEngine {
    const val DEFAULT_POOL_TEXT = """射手：温迪、甘雨、宵宫、提纳里、公子
打野：绫华、胡桃、雷神、刻晴、牢大
中路：希格雯、钟离、八重、龙王、少女、夜兰、纳西妲
战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈"""

    private val roleSeparator = Regex("[、,，\\s]+")
    private val lastGameRolePattern = Regex("[\\u4e00-\\u9fa5a-zA-Z]+")

    fun parseRolePool(text: String): List<RoleCategory> {
        val categories = linkedMapOf<String, List<String>>()

        text.lineSequence().forEach { rawLine ->
            val line = rawLine.trim()
            if (line.isEmpty()) return@forEach

            val separatorIndex = line.indexOfFirst { it == '：' || it == ':' }
            if (separatorIndex < 0) return@forEach

            val name = line.substring(0, separatorIndex).trim()
            val roles = line.substring(separatorIndex + 1)
                .trim()
                .split(roleSeparator)
                .filter(String::isNotEmpty)

            if (name.isNotEmpty() && roles.isNotEmpty()) {
                // LinkedHashMap matches JavaScript object behavior: replacing a category
                // keeps its original position while updating its role list.
                categories[name] = roles
            }
        }

        return categories.map { (name, roles) -> RoleCategory(name, roles) }
    }

    fun parseLastGameRoles(text: String): Set<String> =
        lastGameRolePattern.findAll(text).map { it.value }.toSet()

    fun generate(
        poolText: String,
        lastGameText: String,
        allowDuplicate: Boolean,
        seed: Long = System.currentTimeMillis(),
    ): GroupingResult {
        val categories = parseRolePool(poolText)
        if (categories.isEmpty()) throw GroupingException.InvalidPool()

        if (!allowDuplicate) {
            categories.firstOrNull { it.roles.size < 2 }?.let {
                throw GroupingException.InsufficientRoles(it.name)
            }
        }

        val previousRoles = parseLastGameRoles(lastGameText)
        val random = Mulberry32(seed.toUInt())
        val rolesA = mutableListOf<String>()
        val rolesB = mutableListOf<String>()

        categories.forEach { category ->
            if (allowDuplicate) {
                rolesA += pickOne(category.roles, previousRoles, random)
                rolesB += pickOne(category.roles, previousRoles, random)
            } else {
                val pair = pickTwoDistinct(category.roles, previousRoles, random)
                if (random.nextUnit() > 0.5) {
                    rolesA += pair.first
                    rolesB += pair.second
                } else {
                    rolesA += pair.second
                    rolesB += pair.first
                }
            }
        }

        val players = (1..categories.size * 2).toMutableList()
        shuffle(players, random)

        return GroupingResult(
            seed = seed,
            playersA = players.take(categories.size),
            playersB = players.drop(categories.size),
            rolesA = rolesA,
            rolesB = rolesB,
        )
    }

    private fun pickOne(
        roles: List<String>,
        previousRoles: Set<String>,
        random: Mulberry32,
    ): String {
        val weights = roles.map { if (it in previousRoles) 0.1 else 1.0 }
        var randomWeight = random.nextUnit() * weights.sum()

        weights.forEachIndexed { index, weight ->
            randomWeight -= weight
            if (randomWeight <= 0.0) return roles[index]
        }

        return roles.last()
    }

    private fun pickTwoDistinct(
        roles: List<String>,
        previousRoles: Set<String>,
        random: Mulberry32,
    ): Pair<String, String> {
        val first = pickOne(roles, previousRoles, random)
        val remaining = roles.filter { it != first }
        if (remaining.isEmpty()) return first to first
        return first to pickOne(remaining, previousRoles, random)
    }

    private fun <T> shuffle(values: MutableList<T>, random: Mulberry32) {
        for (index in values.lastIndex downTo 1) {
            val randomIndex = (random.nextUnit() * (index + 1)).toInt()
            val temporary = values[index]
            values[index] = values[randomIndex]
            values[randomIndex] = temporary
        }
    }
}

private class Mulberry32(private var state: UInt) {
    fun nextUnit(): Double {
        state += 0x6D2B79F5u
        var value = state
        value = (value xor (value shr 15)) * (value or 1u)
        value = value xor (value + ((value xor (value shr 7)) * (value or 61u)))
        value = value xor (value shr 14)
        return value.toDouble() / 4_294_967_296.0
    }
}

