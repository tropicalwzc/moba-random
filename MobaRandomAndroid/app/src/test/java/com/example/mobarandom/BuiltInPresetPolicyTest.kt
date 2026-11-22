package com.example.mobarandom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BuiltInPresetPolicyTest {
    private val android30 = """射手：温迪、甘雨、宵宫、提纳里、公子、夜兰
打野：绫华、胡桃、雷神、刻晴、牢大
中路：希格雯、钟离、神子、龙王、少女、纳西妲、可莉
战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、迪卢克、洛恩、琴、杜林"""

    @Test
    fun freshInstallAppliesPreset() {
        assertEquals(BuiltInPresetAction.APPLY_PRESET, BuiltInPresetPolicy.decide(null, false))
        assertEquals(BuiltInPresetAction.APPLY_PRESET, BuiltInPresetPolicy.decide("   ", false))
    }

    @Test
    fun knownLegacyDefaultUpgrades() {
        assertEquals(BuiltInPresetAction.APPLY_PRESET, BuiltInPresetPolicy.decide(android30, false))
        assertEquals(
            BuiltInPresetAction.APPLY_PRESET,
            BuiltInPresetPolicy.decide(GroupingEngine.DEFAULT_POOL_TEXT, false),
        )
    }

    @Test
    fun customPoolIsPreserved() {
        assertEquals(
            BuiltInPresetAction.PRESERVE_CUSTOM,
            BuiltInPresetPolicy.decide("射手：自定义甲、自定义乙", false),
        )
    }

    @Test
    fun existingMarkerWins() {
        assertEquals(
            BuiltInPresetAction.ALREADY_APPLIED,
            BuiltInPresetPolicy.decide(android30, true),
        )
    }

    @Test
    fun normalizationIgnoresLineEndingsAndOuterWhitespace() {
        val spaced = "\r\n  " + android30.lineSequence().joinToString("\r\n  ") + "\r\n"
        assertTrue(BuiltInPresetPolicy.isKnownDefault(spaced))
    }

    @Test
    fun failedPresetCanRetryAfterDefaultPoolWasWritten() {
        val invalid = runCatching {
            RoleWeightTransfer.importJson("{not-json", listOf("射手", "打野", "中路", "战士"))
        }
        assertTrue(invalid.isFailure)
        assertEquals(
            BuiltInPresetAction.APPLY_PRESET,
            BuiltInPresetPolicy.decide(GroupingEngine.DEFAULT_POOL_TEXT, false),
        )
    }
}
