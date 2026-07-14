package com.example.mobarandom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class GroupingEngineTest {
    @Test
    fun defaultPoolParsingPreservesOrderAndCounts() {
        val categories = GroupingEngine.parseRolePool(GroupingEngine.DEFAULT_POOL_TEXT)

        assertEquals(listOf("射手", "打野", "中路", "战士"), categories.map { it.name })
        assertEquals(listOf(5, 5, 7, 8), categories.map { it.roles.size })
    }

    @Test
    fun parserSupportsWebSeparatorsAndCustomCategories() {
        val categories = GroupingEngine.parseRolePool(
            "辅助：角色甲 角色乙、角色丙,角色丁，角色戊\n游走: 角色己 角色庚"
        )

        assertEquals(2, categories.size)
        assertEquals("辅助", categories[0].name)
        assertEquals(listOf("角色甲", "角色乙", "角色丙", "角色丁", "角色戊"), categories[0].roles)
    }

    @Test
    fun fixedSeedMatchesOriginalJavaScriptAlgorithm() {
        val result = GroupingEngine.generate(
            poolText = GroupingEngine.DEFAULT_POOL_TEXT,
            lastGameText = "温迪, 胡桃, 钟离, 行秋",
            allowDuplicate = false,
            seed = 1_700_000_000_123,
        )

        assertEquals(listOf("甘雨", "胡桃", "希格雯", "班尼特"), result.rolesA)
        assertEquals(listOf("公子", "牢大", "龙王", "丝柯克"), result.rolesB)
        assertEquals(listOf(5, 8, 2, 7), result.playersA)
        assertEquals(listOf(3, 6, 4, 1), result.playersB)
    }

    @Test
    fun nonMirrorModeRejectsSingleRoleCategory() {
        assertThrows(GroupingException.InsufficientRoles::class.java) {
            GroupingEngine.generate("射手：温迪", "", false, seed = 1)
        }
    }

    @Test
    fun mirrorModeAcceptsSingleRoleCategory() {
        val result = GroupingEngine.generate("射手：温迪", "", true, seed = 1)

        assertEquals(listOf("温迪"), result.rolesA)
        assertEquals(listOf("温迪"), result.rolesB)
        assertEquals(setOf(1, 2), (result.playersA + result.playersB).toSet())
    }

    @Test
    fun replacementCandidatesStayInCategoryAndExcludeCurrentRole() {
        val pool = "射手：A、B、C、D\n打野：E、F"
        val result = GroupingEngine.generate(pool, "", true, seed = 10)
        val current = result.role(ResultTeam.A, 0)!!

        val candidates = GroupingEngine.replacementCandidates(
            result, ResultTeam.A, 0, pool, allowDuplicate = true
        )

        assertEquals(setOf("A", "B", "C", "D") - current, candidates.toSet())
    }

    @Test
    fun replacementCandidatesPreserveNonMirrorUniqueness() {
        val pool = "射手：A、B、C、D"
        val result = GroupingEngine.generate(pool, "", false, seed = 10)
        val candidates = GroupingEngine.replacementCandidates(
            result, ResultTeam.A, 0, pool, allowDuplicate = false
        )

        assertEquals(2, candidates.size)
        assert(!candidates.contains(result.role(ResultTeam.A, 0)))
        assert(!candidates.contains(result.role(ResultTeam.B, 0)))
    }

    @Test
    fun replacingRoleOnlyChangesRequestedSlot() {
        val original = GroupingEngine.generate(
            "射手：A、B、C\n打野：D、E、F", "", false, seed = 10
        )

        val updated = original.replacingRole(ResultTeam.B, 1, "F")!!

        assertEquals(original.rolesA, updated.rolesA)
        assertEquals(original.rolesB[0], updated.rolesB[0])
        assertEquals("F", updated.rolesB[1])
        assertEquals(original.playersA, updated.playersA)
        assertEquals(original.playersB, updated.playersB)
    }
}
