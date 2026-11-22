package com.example.mobarandom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class Bo3AvatarIndexTest {
    @Test
    fun bundledIndexLoadsAvatarsAndAliases() {
        val file = File("src/main/assets/BO3/avatar-index.json")
        assertTrue("missing avatar index at ${file.absolutePath}", file.isFile)
        val index = Bo3AvatarIndex.fromJson(file.readText())
        assertNotNull(index)
        assertEquals(131, index!!.avatarCount)
        assertTrue(index.aliasCount > 0)

        val alias = index.descriptor("公子")
        assertEquals("达达利亚", alias.officialName)
        assertEquals("a115", alias.file)
        assertEquals("水", alias.element)

        val unknown = index.descriptor("未知角色")
        assertNull(unknown.file)
        assertEquals("未知角色", unknown.displayName)
        assertEquals(Bo3Palette.hash("未知角色"), unknown.fallbackSeed)
    }
}
