import Foundation

/// BO3-specific view of the shared role-pool text. Category order comes from
/// the grouping parser; characters are deduplicated across categories so a
/// ban or pick can only ever reference one pool entry.
struct Bo3Pool: Equatable, Sendable {
    struct Category: Equatable, Sendable {
        let name: String
        let heroes: [String]
    }

    let categories: [Category]
    let heroRole: [String: String]
    let duplicates: [String]

    init(text: String) {
        let parsed = GroupingEngine.parseRolePool(text)
        var seen = Set<String>()
        var categories: [Category] = []
        var heroRole: [String: String] = [:]
        var duplicates: [String] = []

        for category in parsed {
            var heroes: [String] = []
            for rawHero in category.roles {
                let hero = rawHero.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !hero.isEmpty else { continue }
                if seen.contains(hero) {
                    duplicates.append(hero)
                    continue
                }
                seen.insert(hero)
                heroes.append(hero)
                heroRole[hero] = category.name
            }
            if !heroes.isEmpty {
                categories.append(Category(name: category.name, heroes: heroes))
            }
        }

        self.categories = categories
        self.heroRole = heroRole
        self.duplicates = duplicates
    }

    var total: Int {
        heroRole.count
    }

    var isEmpty: Bool {
        categories.isEmpty
    }

    var allHeroes: [String] {
        categories.flatMap(\.heroes)
    }

    func role(for hero: String) -> String? {
        heroRole[hero]
    }

    func contains(_ hero: String) -> Bool {
        heroRole[hero] != nil
    }
}
