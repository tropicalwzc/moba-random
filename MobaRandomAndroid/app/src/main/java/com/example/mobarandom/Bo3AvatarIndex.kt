package com.example.mobarandom

import org.json.JSONObject

data class Bo3AvatarDescriptor(
    val displayName: String,
    val officialName: String?,
    val file: String?,
    val element: String?,
    val fallbackSeed: Int,
) {
    val hasImage: Boolean
        get() = file != null
}

class Bo3AvatarIndex(
    private val aliases: Map<String, String>,
    private val avatars: Map<String, Entry>,
) {
    data class Entry(val file: String, val element: String)

    val avatarCount: Int
        get() = avatars.size

    val aliasCount: Int
        get() = aliases.size

    fun descriptor(name: String): Bo3AvatarDescriptor {
        val display = name.trim()
        val official = aliases[display] ?: display
        val entry = avatars[official]
        return Bo3AvatarDescriptor(
            displayName = display.ifEmpty { "?" },
            officialName = official.takeIf { entry != null },
            file = entry?.file,
            element = entry?.element,
            fallbackSeed = Bo3Palette.hash(display),
        )
    }

    companion object {
        fun fromJson(raw: String): Bo3AvatarIndex? = runCatching {
            val root = JSONObject(raw)
            val aliasesObject = root.optJSONObject("aliases")
            val avatarsObject = root.optJSONObject("avatars") ?: return null
            val aliases = if (aliasesObject == null) emptyMap() else {
                aliasesObject.keys().asSequence().associateWith { aliasesObject.getString(it) }
            }
            val avatars = avatarsObject.keys().asSequence().associateWith { name ->
                val value = avatarsObject.getJSONObject(name)
                Entry(
                    file = value.getString("file"),
                    element = value.optString("element", ""),
                )
            }
            Bo3AvatarIndex(aliases, avatars)
        }.getOrNull()
    }
}
