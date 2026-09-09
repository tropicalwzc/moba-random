package com.example.mobarandom

data class RoleCategory(val name: String, val roles: List<String>)

data class CharacterLaneWeights(
    val character: String,
    val laneWeights: Map<String, Int>,
    val sourceLane: String? = null,
)

data class RoleWeightConfiguration(
    val version: Int = CURRENT_VERSION,
    val characters: List<CharacterLaneWeights>,
) {
    fun weight(character: String, lane: String): Int =
        characters.firstOrNull { it.character == character }?.laneWeights?.get(lane) ?: 0

    fun isValid(lanes: List<String>): Boolean {
        val laneSet = lanes.toSet()
        return version == CURRENT_VERSION && characters.all { entry ->
            entry.laneWeights.keys.all { it in laneSet } &&
                entry.laneWeights.values.all { it >= 0 } &&
                lanes.sumOf { entry.laneWeights[it] ?: 0 } == 100
        }
    }

    companion object {
        const val CURRENT_VERSION = 1

        fun reconcile(categories: List<RoleCategory>, saved: RoleWeightConfiguration?): RoleWeightConfiguration {
            val lanes = categories.map { it.name }
            val laneSet = lanes.toSet()
            val characterOrder = mutableListOf<String>()
            val defaultLanes = linkedMapOf<String, String>()
            categories.forEach { category ->
                category.roles.forEach { character ->
                    if (character !in defaultLanes) {
                        defaultLanes[character] = category.name
                        characterOrder += character
                    }
                }
            }
            val savedByName = if (saved?.version == CURRENT_VERSION) {
                saved.characters.associateBy { it.character }
            } else emptyMap()
            val entries = characterOrder.map { character ->
                val defaultLane = requireNotNull(defaultLanes[character])
                val fallback = oneHot(character, defaultLane, lanes)
                val old = savedByName[character]
                if (old == null || old.laneWeights.values.any { it < 0 }) {
                    fallback
                } else if (old.sourceLane != null && old.sourceLane != defaultLane) {
                    fallback
                } else {
                    val weights = lanes.associateWithTo(linkedMapOf()) { old.laneWeights[it] ?: 0 }
                    val removedWeight = old.laneWeights.entries.filter { it.key !in laneSet }.sumOf { it.value }
                    weights[defaultLane] = (weights[defaultLane] ?: 0) + removedWeight
                    if (weights.values.sum() == 100) {
                        CharacterLaneWeights(character, weights, sourceLane = defaultLane)
                    } else fallback
                }
            }
            return RoleWeightConfiguration(characters = entries)
        }

        fun normalizeToHundred(values: List<Int>): List<Int>? {
            if (values.any { it < 0 }) return null
            val total = values.sum()
            if (total <= 100) return values
            val divisor = total.toLong()
            val products = values.map { it.toLong() * 100L }
            val result = products.map { (it / divisor).toInt() }.toMutableList()
            val order = products.indices.sortedWith(
                compareByDescending<Int> { products[it] % divisor }.thenBy { it }
            )
            var remaining = 100 - result.sum()
            var cursor = 0
            while (remaining > 0) {
                result[order[cursor]] += 1
                remaining -= 1
                cursor += 1
            }
            return result
        }

        private fun oneHot(character: String, defaultLane: String, lanes: List<String>) =
            CharacterLaneWeights(
                character,
                lanes.associateWithTo(linkedMapOf()) { if (it == defaultLane) 100 else 0 },
                sourceLane = defaultLane,
            )
    }
}

enum class ResultTeam { A, B }

data class RoleSlot(val team: ResultTeam, val index: Int)

data class GroupingResult(
    val seed: Long,
    val playersA: List<Int>,
    val playersB: List<Int>,
    val rolesA: List<String>,
    val rolesB: List<String>,
) {
    fun role(team: ResultTeam, index: Int): String? =
        (if (team == ResultTeam.A) rolesA else rolesB).getOrNull(index)

    fun replacingRole(team: ResultTeam, index: Int, role: String): GroupingResult? {
        if (this.role(team, index) == null) return null
        val updatedRolesA = rolesA.toMutableList()
        val updatedRolesB = rolesB.toMutableList()
        if (team == ResultTeam.A) updatedRolesA[index] = role else updatedRolesB[index] = role
        return copy(rolesA = updatedRolesA, rolesB = updatedRolesB)
    }

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
    class InvalidPool : GroupingException("角色池格式不正确或为空。请确保每行格式为：职业名：角色1、角色2")
    class InsufficientRoles(category: String) : GroupingException(
        "职业“$category”的可用角色数量不足 2 个。请调整分路权重、补充角色，或开启镜像模式。"
    )
    class ImpossibleWeightConfiguration : GroupingException(
        "当前分路权重无法组成完整且不重复的阵容。请调整权重、补充角色，或开启镜像模式。"
    )
}

object GroupingEngine {
    const val HISTORY_LIMIT = 100
    const val DEFAULT_POOL_TEXT = """射手：温迪、甘雨、宵宫、提纳里、公子、夜兰
打野：绫华、胡桃、雷神、刻晴、牢大
中路：希格雯、钟离、神子、龙王、少女、纳西妲、可莉
战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、迪卢克、洛恩、琴、杜林"""

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
            val roles = line.substring(separatorIndex + 1).trim().split(roleSeparator).filter(String::isNotEmpty)
            if (name.isNotEmpty()) categories[name] = roles
        }
        return categories.map { (name, roles) -> RoleCategory(name, roles) }
    }

    fun parseLastGameRoles(text: String): Set<String> =
        lastGameRolePattern.findAll(text).map { it.value }.toSet()

    fun previousRolesText(result: GroupingResult?): String =
        result?.let { (it.rolesA + it.rolesB).joinToString("，") }.orEmpty()

    fun effectiveWeight(
        character: String,
        lane: String,
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>,
    ): Double = configuration.weight(character, lane) / 100.0 *
        if (character in previousRoles) 0.1 else 1.0

    fun generate(
        poolText: String,
        lastGameText: String,
        allowDuplicate: Boolean,
        weightConfiguration: RoleWeightConfiguration? = null,
        seed: Long = System.currentTimeMillis(),
    ): GroupingResult {
        val categories = parseRolePool(poolText)
        if (categories.isEmpty()) throw GroupingException.InvalidPool()
        val configuration = RoleWeightConfiguration.reconcile(categories, weightConfiguration)
        if (!allowDuplicate) {
            categories.firstOrNull { category ->
                configuration.characters.count { configuration.weight(it.character, category.name) > 0 } < 2
            }?.let { throw GroupingException.InsufficientRoles(it.name) }
        }
        val previousRoles = parseLastGameRoles(lastGameText)
        val random = Mulberry32(seed.toUInt())
        val rolesA: List<String>
        val rolesB: List<String>
        if (allowDuplicate) {
            val assignmentA = assign(
                categories.indices.map { AssignmentSlot(ResultTeam.A, it) }, categories, configuration, previousRoles, random
            ) ?: throw GroupingException.ImpossibleWeightConfiguration()
            val assignmentB = assign(
                categories.indices.map { AssignmentSlot(ResultTeam.B, it) }, categories, configuration, previousRoles, random
            ) ?: throw GroupingException.ImpossibleWeightConfiguration()
            rolesA = orderedRoles(assignmentA, ResultTeam.A, categories.size)
            rolesB = orderedRoles(assignmentB, ResultTeam.B, categories.size)
        } else {
            val slots = categories.indices.flatMap {
                listOf(AssignmentSlot(ResultTeam.A, it), AssignmentSlot(ResultTeam.B, it))
            }
            val assignment = assign(slots, categories, configuration, previousRoles, random)
                ?: throw GroupingException.ImpossibleWeightConfiguration()
            rolesA = orderedRoles(assignment, ResultTeam.A, categories.size)
            rolesB = orderedRoles(assignment, ResultTeam.B, categories.size)
        }
        val players = (1..categories.size * 2).toMutableList()
        shuffle(players, random)
        return GroupingResult(seed, players.take(categories.size), players.drop(categories.size), rolesA, rolesB)
    }

    fun replacementCandidates(
        result: GroupingResult,
        team: ResultTeam,
        index: Int,
        poolText: String,
        allowDuplicate: Boolean,
        weightConfiguration: RoleWeightConfiguration? = null,
    ): List<String> {
        val categories = parseRolePool(poolText)
        val category = categories.getOrNull(index) ?: return emptyList()
        val currentRole = result.role(team, index) ?: return emptyList()
        val configuration = RoleWeightConfiguration.reconcile(categories, weightConfiguration)
        val forbidden = if (allowDuplicate) {
            (if (team == ResultTeam.A) result.rolesA else result.rolesB).toSet()
        } else (result.rolesA + result.rolesB).toSet()
        return configuration.characters.map { it.character }.filter {
            it != currentRole && it !in forbidden && configuration.weight(it, category.name) > 0
        }
    }

    fun replacementRole(
        result: GroupingResult,
        team: ResultTeam,
        index: Int,
        poolText: String,
        lastGameText: String,
        allowDuplicate: Boolean,
        weightConfiguration: RoleWeightConfiguration? = null,
        seed: Long = System.currentTimeMillis(),
    ): String? {
        val categories = parseRolePool(poolText)
        val category = categories.getOrNull(index) ?: return null
        val configuration = RoleWeightConfiguration.reconcile(categories, weightConfiguration)
        val candidates = replacementCandidates(result, team, index, poolText, allowDuplicate, configuration)
        return pickWeighted(
            candidates, category.name, configuration, parseLastGameRoles(lastGameText), Mulberry32(seed.toUInt())
        )
    }

    private data class AssignmentSlot(val team: ResultTeam, val laneIndex: Int)

    private fun orderedRoles(assignment: Map<AssignmentSlot, String>, team: ResultTeam, count: Int): List<String> =
        (0 until count).mapNotNull { assignment[AssignmentSlot(team, it)] }

    private fun assign(
        slots: List<AssignmentSlot>,
        categories: List<RoleCategory>,
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>,
        random: Mulberry32,
    ): Map<AssignmentSlot, String>? = search(
        slots, emptySet(), emptyMap(), categories, configuration, previousRoles, random
    )

    private fun search(
        remaining: List<AssignmentSlot>,
        used: Set<String>,
        assignment: Map<AssignmentSlot, String>,
        categories: List<RoleCategory>,
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>,
        random: Mulberry32,
    ): Map<AssignmentSlot, String>? {
        if (remaining.isEmpty()) return assignment
        val selected = remaining.withIndex().minWithOrNull(
            compareBy<IndexedValue<AssignmentSlot>> { indexed ->
                val lane = categories[indexed.value.laneIndex].name
                configuration.characters.count {
                    it.character !in used && configuration.weight(it.character, lane) > 0
                }
            }.thenBy { it.index }
        ) ?: return null
        val lane = categories[selected.value.laneIndex].name
        val candidates = configuration.characters.map { it.character }.filter {
            it !in used && configuration.weight(it, lane) > 0
        }
        if (candidates.isEmpty()) return null
        val orderedCandidates = weightedOrder(candidates, lane, configuration, previousRoles, random)
        val nextRemaining = remaining.toMutableList().also { it.removeAt(selected.index) }
        for (character in orderedCandidates) {
            val result = search(
                nextRemaining,
                used + character,
                assignment + (selected.value to character),
                categories,
                configuration,
                previousRoles,
                random,
            )
            if (result != null) return result
        }
        return null
    }

    private fun weightedOrder(
        characters: List<String>,
        lane: String,
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>,
        random: Mulberry32,
    ): List<String> {
        val remaining = characters.toMutableList()
        val result = mutableListOf<String>()
        while (remaining.isNotEmpty()) {
            val next = pickWeighted(remaining, lane, configuration, previousRoles, random) ?: break
            result += next
            remaining.removeAll { it == next }
        }
        return result
    }

    private fun pickWeighted(
        characters: List<String>,
        lane: String,
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>,
        random: Mulberry32,
    ): String? {
        val weighted = characters.map {
            it to effectiveWeight(it, lane, configuration, previousRoles)
        }.filter { it.second > 0.0 }
        if (weighted.isEmpty()) return null
        var randomWeight = random.nextUnit() * weighted.sumOf { it.second }
        weighted.forEach { item ->
            randomWeight -= item.second
            if (randomWeight <= 0.0) return item.first
        }
        return weighted.last().first
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
