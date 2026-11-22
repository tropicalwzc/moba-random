package com.example.mobarandom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class RoleWeightPresetTest {
    @Test
    fun bundledPresetMatchesThe34CharacterDefaultPool() {
        val file = File("src/main/res/raw/default_role_weights_v2.json")
        assertTrue("missing bundled preset at ${file.absolutePath}", file.isFile)
        val lanes = GroupingEngine.parseRolePool(GroupingEngine.DEFAULT_POOL_TEXT).map { it.name }
        val imported = RoleWeightTransfer.importJson(file.readText(), lanes)

        assertEquals(34, imported.configuration.characters.size)
        assertEquals(GroupingEngine.DEFAULT_POOL_TEXT, imported.poolText)
        assertTrue(imported.configuration.characters.all { it.laneWeights.values.sum() == 100 })
    }
}
