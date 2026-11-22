package com.example.mobarandom

/**
 * The BO3 pool is the shared role-pool text parsed into unique heroes.
 * Categories are only recommendations; a hero belongs to its first category.
 */
class Bo3Pool(text: String) {
    data class Category(val name: String, val heroes: List<String>)

    val categories: List<Category>
    val heroRole: Map<String, String>
    val duplicates: List<String>

    init {
        val seen = mutableSetOf<String>()
        val parsedCategories = mutableListOf<Category>()
        val roles = linkedMapOf<String, String>()
        val duplicateList = mutableListOf<String>()

        GroupingEngine.parseRolePool(text).forEach { category ->
            val heroes = mutableListOf<String>()
            category.roles.forEach { raw ->
                val hero = raw.trim()
                if (hero.isEmpty()) return@forEach
                if (!seen.add(hero)) {
                    duplicateList += hero
                    return@forEach
                }
                heroes += hero
                roles[hero] = category.name
            }
            if (heroes.isNotEmpty()) {
                parsedCategories += Category(category.name, heroes)
            }
        }

        categories = parsedCategories
        heroRole = roles
        duplicates = duplicateList
    }

    val total: Int
        get() = heroRole.size

    val isEmpty: Boolean
        get() = categories.isEmpty()

    val allHeroes: List<String>
        get() = categories.flatMap { it.heroes }

    fun role(hero: String): String? = heroRole[hero]

    fun contains(hero: String): Boolean = heroRole.containsKey(hero)
}
