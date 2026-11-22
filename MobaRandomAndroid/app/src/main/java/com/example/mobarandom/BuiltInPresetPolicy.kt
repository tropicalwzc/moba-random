package com.example.mobarandom

enum class BuiltInPresetAction {
    ALREADY_APPLIED,
    PRESERVE_CUSTOM,
    APPLY_PRESET,
}

/**
 * Pure decision logic for the one-time bundled preset migration. Custom pools
 * from pre-marker upgrades are preserved; only fresh installs and known
 * built-in defaults are replaced by the current 34-character roster.
 */
object BuiltInPresetPolicy {
    private val legacyDefaults = listOf(
        // Android 1.2 default.
        """射手：温迪、甘雨、宵宫、提纳里、公子、夜兰
打野：绫华、胡桃、雷神、刻晴、牢大
中路：希格雯、钟离、神子、龙王、少女、纳西妲、可莉
战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、迪卢克、洛恩、琴、杜林""",
        // Earlier iOS roster with 夜空 and 神子.
        """射手：温迪、甘雨、宵宫、提纳里、公子、夜兰
打野：绫华、胡桃、雷神、刻晴、牢大
中路：希格雯、钟离、神子、龙王、少女、纳西妲、可莉
战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、迪卢克、洛恩、琴、杜林""",
        // Earlier iOS roster with 八重 and 夜兰 in mid.
        """射手：温迪、甘雨、宵宫、提纳里、公子
打野：绫华、胡桃、雷神、刻晴、牢大
中路：希格雯、钟离、八重、龙王、少女、夜兰、纳西妲
战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈""",
        // Reference-page 34 variants.
        """射手：温迪、甘雨、宵宫、提纳里、公子、夜兰、赛索斯
打野：绫华、胡桃、雷神、刻晴、牢大
中路：希格雯、钟离、八重、龙王、少女、纳西妲、可莉
战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、琴、洛恩、迪卢克、杜林、法尔加、克洛林德、赛诺""",
        """射手：温迪、甘雨、宵宫、提纳里、公子、夜兰、赛索斯
打野：绫华、胡桃、雷神、刻晴、牢大、魈
中路：希格雯、钟离、八重、龙王、少女、纳西妲、可莉
战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、琴、洛恩、迪卢克、杜林、法尔加、克洛林德、赛诺""",
    )

    private val knownDefaults: Set<String> by lazy {
        (legacyDefaults + GroupingEngine.DEFAULT_POOL_TEXT).map(::normalize).toSet()
    }

    fun decide(storedPool: String?, markerApplied: Boolean): BuiltInPresetAction {
        if (markerApplied) return BuiltInPresetAction.ALREADY_APPLIED
        val normalized = normalize(storedPool.orEmpty())
        if (normalized.isEmpty()) return BuiltInPresetAction.APPLY_PRESET
        return if (normalized in knownDefaults) {
            BuiltInPresetAction.APPLY_PRESET
        } else {
            BuiltInPresetAction.PRESERVE_CUSTOM
        }
    }

    fun isKnownDefault(text: String): Boolean = normalize(text) in knownDefaults

    fun normalize(text: String): String = text
        .replace("\r\n", "\n")
        .replace('\r', '\n')
        .lineSequence()
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .joinToString("\n")
}
