package com.example.mobarandom

import org.junit.Assert.assertEquals
import org.junit.Test

class Bo3LayoutModeTest {
    @Test
    fun phonePortraitIsCompact() {
        assertEquals(Bo3LayoutMode.COMPACT, Bo3LayoutMode.forSize(393, 852))
        assertEquals(Bo3LayoutMode.COMPACT, Bo3LayoutMode.forSize(599, 900))
    }

    @Test
    fun phoneLandscapeAndTabletPortraitUseTwoColumns() {
        assertEquals(Bo3LayoutMode.TWO_COLUMN, Bo3LayoutMode.forSize(800, 360))
        assertEquals(Bo3LayoutMode.TWO_COLUMN, Bo3LayoutMode.forSize(800, 1_200))
    }

    @Test
    fun largeLandscapeUsesThreeColumnsButHeightGuardStillApplies() {
        assertEquals(Bo3LayoutMode.THREE_COLUMN, Bo3LayoutMode.forSize(1_280, 800))
        assertEquals(Bo3LayoutMode.TWO_COLUMN, Bo3LayoutMode.forSize(1_280, 599))
    }
}
