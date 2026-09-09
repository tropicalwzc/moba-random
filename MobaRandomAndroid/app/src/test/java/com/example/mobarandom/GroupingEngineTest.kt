package com.example.mobarandom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class GroupingEngineTest {
    @Test
    fun defaultPoolParsingPreservesOrderAndCounts() {
        val categories = GroupingEngine.parseRolePool(GroupingEngine.DEFAULT_POOL_TEXT)

        assertEquals(listOf("射手", "打野", "中路", "战士"), categories.map { it.name })
        assertEquals(listOf(6, 5, 7, 12), categories.map { it.roles.size })
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
    fun fixedSeedMatchesWeightedCrossClientAlgorithm() {
        val result = GroupingEngine.generate(
            poolText = GroupingEngine.DEFAULT_POOL_TEXT,
            lastGameText = "温迪, 胡桃, 钟离, 行秋",
            allowDuplicate = false,
            seed = 1_700_000_000_123,
        )

        assertEquals(listOf("提纳里", "绫华", "神子", "女仆"), result.rolesA)
        assertEquals(listOf("公子", "胡桃", "纳西妲", "点刀"), result.rolesB)
        assertEquals(listOf(8, 2, 1, 6), result.playersA)
        assertEquals(listOf(7, 4, 5, 3), result.playersB)
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

    @Test
    fun defaultWeightsUseFirstListedLaneAndDeduplicateCharacters() {
        val categories = GroupingEngine.parseRolePool("射手：A、B\n中路：A、C")
        val configuration = RoleWeightConfiguration.reconcile(categories, null)

        assertEquals(listOf("A", "B", "C"), configuration.characters.map { it.character })
        assertEquals(mapOf("射手" to 100, "中路" to 0), configuration.characters[0].laneWeights)
        assertEquals(mapOf("射手" to 0, "中路" to 100), configuration.characters[2].laneWeights)
        assert(configuration.isValid(listOf("射手", "中路")))
    }

    @Test
    fun largestRemainderNormalizationMatchesGoldenCases() {
        assertEquals(listOf(82, 18, 0, 0), RoleWeightConfiguration.normalizeToHundred(listOf(90, 20, 0, 0)))
        assertEquals(listOf(100, 0, 0, 0), RoleWeightConfiguration.normalizeToHundred(listOf(120, 0, 0, 0)))
        assertEquals(listOf(34, 33, 33), RoleWeightConfiguration.normalizeToHundred(listOf(101, 101, 101)))
        assertEquals(listOf(1, 1, 1), RoleWeightConfiguration.normalizeToHundred(listOf(1, 1, 1)))
        assertEquals(null, RoleWeightConfiguration.normalizeToHundred(listOf(-1, 101)))
    }

    @Test
    fun reconciliationTransfersRemovedLaneWeightAndAddsDefaults() {
        val saved = RoleWeightConfiguration(characters = listOf(
            CharacterLaneWeights("A", mapOf("射手" to 80, "中路" to 20)),
            CharacterLaneWeights("B", mapOf("射手" to 100, "中路" to 0)),
            CharacterLaneWeights("C", mapOf("射手" to 0, "中路" to 100)),
        ))
        val result = RoleWeightConfiguration.reconcile(
            GroupingEngine.parseRolePool("射手：A、D\n打野：C"), saved
        )

        assertEquals(listOf("A", "D", "C"), result.characters.map { it.character })
        assertEquals(mapOf("射手" to 100, "打野" to 0), result.characters.first { it.character == "A" }.laneWeights)
        assertEquals(mapOf("射手" to 0, "打野" to 100), result.characters.first { it.character == "C" }.laneWeights)
        assertEquals(mapOf("射手" to 100, "打野" to 0), result.characters.first { it.character == "D" }.laneWeights)
    }

    @Test
    fun configuredAndPreviousGameWeightsCompose() {
        val configuration = RoleWeightConfiguration(characters = listOf(
            CharacterLaneWeights("A", mapOf("射手" to 80, "中路" to 20))
        ))
        assertEquals(0.08, GroupingEngine.effectiveWeight("A", "射手", configuration, setOf("A")), 0.000001)
        assertEquals(0.2, GroupingEngine.effectiveWeight("A", "中路", configuration, emptySet()), 0.000001)
    }

    @Test
    fun movingCharacterToAnotherLaneResetsItsWeights() {
        val saved = RoleWeightConfiguration(characters = listOf(
            CharacterLaneWeights("A", mapOf("射手" to 80, "中路" to 20), sourceLane = "射手"),
            CharacterLaneWeights("B", mapOf("射手" to 70, "中路" to 30), sourceLane = "射手"),
        ))

        val result = RoleWeightConfiguration.reconcile(
            GroupingEngine.parseRolePool("射手：B\n中路：A"), saved
        )

        assertEquals(mapOf("射手" to 0, "中路" to 100), result.characters.first { it.character == "A" }.laneWeights)
        assertEquals("中路", result.characters.first { it.character == "A" }.sourceLane)
        assertEquals(mapOf("射手" to 70, "中路" to 30), result.characters.first { it.character == "B" }.laneWeights)
    }

    @Test
    fun legacyWeightsGainSourceLaneWithoutBeingReset() {
        val saved = RoleWeightConfiguration(characters = listOf(
            CharacterLaneWeights("A", mapOf("射手" to 35, "中路" to 65)),
        ))

        val result = RoleWeightConfiguration.reconcile(
            GroupingEngine.parseRolePool("射手：A\n中路：B"), saved
        )

        assertEquals(mapOf("射手" to 35, "中路" to 65), result.characters.first().laneWeights)
        assertEquals("射手", result.characters.first().sourceLane)
    }

    @Test
    fun previousRolesTextUsesBothTeamsAndEmptyInitialState() {
        assertEquals("", GroupingEngine.previousRolesText(null))

        val result = GroupingResult(
            seed = 1,
            playersA = listOf(1, 2),
            playersB = listOf(3, 4),
            rolesA = listOf("A", "B"),
            rolesB = listOf("C", "D"),
        )
        val text = GroupingEngine.previousRolesText(result)

        assertEquals("A，B，C，D", text)
        assertEquals(setOf("A", "B", "C", "D"), GroupingEngine.parseLastGameRoles(text))
    }

    @Test
    fun normalAndMirrorModesEnforceExpectedUniqueness() {
        val pool = "射手：A、B、C、D\n中路：A、B、C、D"
        val configuration = RoleWeightConfiguration(characters = listOf("A", "B", "C", "D").map {
            CharacterLaneWeights(it, mapOf("射手" to 50, "中路" to 50))
        })
        val normal = GroupingEngine.generate(pool, "", false, configuration, seed = 77)
        val mirror = GroupingEngine.generate(pool, "", true, configuration, seed = 91)

        assertEquals(4, (normal.rolesA + normal.rolesB).toSet().size)
        assertEquals(2, mirror.rolesA.toSet().size)
        assertEquals(2, mirror.rolesB.toSet().size)
    }

    @Test
    fun impossibleGlobalAssignmentThrowsWeightConfigurationError() {
        val pool = "射手：A、B\n中路：A、B"
        val configuration = RoleWeightConfiguration(characters = listOf("A", "B").map {
            CharacterLaneWeights(it, mapOf("射手" to 50, "中路" to 50))
        })

        assertThrows(GroupingException.ImpossibleWeightConfiguration::class.java) {
            GroupingEngine.generate(pool, "", false, configuration, seed = 1)
        }
    }

    @Test
    fun importedWeightsBuildCanonicalHomepagePoolUsingLaneOrderForTies() {
        val imported = RoleWeightTransfer.validatedImport(
            lanes = listOf("射手", "打野", "中路", "战士"),
            characters = listOf(
                CharacterLaneWeights("温迪", mapOf("射手" to 80, "中路" to 20)),
                CharacterLaneWeights("夜兰", mapOf("射手" to 50, "中路" to 50)),
                CharacterLaneWeights("绫华", mapOf("打野" to 100)),
                CharacterLaneWeights("钟离", mapOf("中路" to 100)),
            ),
        )

        assertEquals(
            "射手：温迪、夜兰\n打野：绫华\n中路：钟离\n战士：",
            imported.poolText,
        )
        assertEquals("射手", imported.configuration.characters.first { it.character == "夜兰" }.sourceLane)
        assertEquals(
            mapOf("射手" to 80, "打野" to 0, "中路" to 20, "战士" to 0),
            imported.configuration.characters.first { it.character == "温迪" }.laneWeights,
        )
        assertEquals(
            listOf("射手", "打野", "中路", "战士"),
            GroupingEngine.parseRolePool(imported.poolText).map { it.name },
        )
    }

    @Test
    fun importedWeightsRejectDuplicateNamesAndInvalidTotals() {
        assertThrows(RoleWeightTransferException::class.java) {
            RoleWeightTransfer.validatedImport(
                lanes = listOf("射手", "中路"),
                characters = listOf(
                    CharacterLaneWeights("A", mapOf("射手" to 80, "中路" to 20)),
                    CharacterLaneWeights("A", mapOf("射手" to 100, "中路" to 0)),
                ),
            )
        }
        assertThrows(RoleWeightTransferException::class.java) {
            RoleWeightTransfer.validatedImport(
                lanes = listOf("射手", "中路"),
                characters = listOf(CharacterLaneWeights("A", mapOf("射手" to 80, "中路" to 10))),
            )
        }
    }

    @Test
    fun weightSettingsGridAdaptsAcrossPhoneAndTabletWidths() {
        assertEquals(1, weightGridColumnCount(599))
        assertEquals(2, weightGridColumnCount(600))
        assertEquals(2, weightGridColumnCount(899))
        assertEquals(3, weightGridColumnCount(900))
        assertEquals(3, weightGridColumnCount(1_024))
    }
}
