import Foundation

struct RoleCategory: Equatable, Sendable {
    let name: String
    let roles: [String]
}

struct GroupingResult: Equatable, Sendable {
    let seed: Int64
    let playersA: [Int]
    let playersB: [Int]
    let rolesA: [String]
    let rolesB: [String]

    var formattedText: String {
        """
        Group A
        \(playersA.map(String.init).joined(separator: "，"))
        \(rolesA.joined(separator: "，"))

        Group B
        \(playersB.map(String.init).joined(separator: "，"))
        \(rolesB.joined(separator: "，"))
        """
    }
}

enum GroupingError: LocalizedError, Equatable, Sendable {
    case invalidPool
    case insufficientRoles(category: String)

    var errorDescription: String? {
        switch self {
        case .invalidPool:
            "角色池格式不正确或为空。请确保每行格式为：职业名：角色1、角色2"
        case let .insufficientRoles(category):
            "职业“\(category)”的角色数量不足 2 个。请补充角色，或开启“允许两组使用相同角色”。"
        }
    }
}

enum GroupingEngine {
    static let defaultPoolText = """
    射手：温迪、甘雨、宵宫、提纳里、公子
    打野：绫华、胡桃、雷神、刻晴、牢大
    中路：希格雯、钟离、八重、龙王、少女、夜兰、纳西妲
    战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈
    """

    static func parseRolePool(_ text: String) -> [RoleCategory] {
        var categories: [RoleCategory] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty,
                  let separatorIndex = line.firstIndex(where: { $0 == "：" || $0 == ":" }) else {
                continue
            }

            let name = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let valuesStart = line.index(after: separatorIndex)
            let values = String(line[valuesStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let roles = values
                .split(whereSeparator: { character in
                    character == "、" || character == "," || character == "，" || character.isWhitespace
                })
                .map(String.init)
                .filter { !$0.isEmpty }

            guard !name.isEmpty, !roles.isEmpty else { continue }

            let category = RoleCategory(name: name, roles: roles)
            if let existingIndex = categories.firstIndex(where: { $0.name == name }) {
                categories[existingIndex] = category
            } else {
                categories.append(category)
            }
        }

        return categories
    }

    static func parseLastGameRoles(_ text: String) -> Set<String> {
        let pattern = #"[\u4e00-\u9fa5a-zA-Z]+"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let source = text as NSString
        let range = NSRange(location: 0, length: source.length)
        return Set(expression.matches(in: text, range: range).map { source.substring(with: $0.range) })
    }

    static func generate(
        poolText: String,
        lastGameText: String,
        allowDuplicate: Bool,
        seed: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)
    ) throws -> GroupingResult {
        let categories = parseRolePool(poolText)
        guard !categories.isEmpty else { throw GroupingError.invalidPool }

        if !allowDuplicate,
           let invalidCategory = categories.first(where: { $0.roles.count < 2 }) {
            throw GroupingError.insufficientRoles(category: invalidCategory.name)
        }

        let previousRoles = parseLastGameRoles(lastGameText)
        var generator = Mulberry32(seed: UInt32(truncatingIfNeeded: seed))
        var rolesA: [String] = []
        var rolesB: [String] = []

        for category in categories {
            if allowDuplicate {
                rolesA.append(pickOne(from: category.roles, previousRoles: previousRoles, using: &generator))
                rolesB.append(pickOne(from: category.roles, previousRoles: previousRoles, using: &generator))
            } else {
                let pair = pickTwoDistinct(
                    from: category.roles,
                    previousRoles: previousRoles,
                    using: &generator
                )
                if generator.nextUnit() > 0.5 {
                    rolesA.append(pair.0)
                    rolesB.append(pair.1)
                } else {
                    rolesA.append(pair.1)
                    rolesB.append(pair.0)
                }
            }
        }

        let playerCountPerGroup = categories.count
        let players = shuffled(Array(1...(playerCountPerGroup * 2)), using: &generator)

        return GroupingResult(
            seed: seed,
            playersA: Array(players.prefix(playerCountPerGroup)),
            playersB: Array(players.dropFirst(playerCountPerGroup)),
            rolesA: rolesA,
            rolesB: rolesB
        )
    }

    private static func pickOne(
        from roles: [String],
        previousRoles: Set<String>,
        using generator: inout Mulberry32
    ) -> String {
        let weights = roles.map { previousRoles.contains($0) ? 0.1 : 1.0 }
        var randomWeight = generator.nextUnit() * weights.reduce(0, +)

        for (index, weight) in weights.enumerated() {
            randomWeight -= weight
            if randomWeight <= 0 {
                return roles[index]
            }
        }

        return roles[roles.count - 1]
    }

    private static func pickTwoDistinct(
        from roles: [String],
        previousRoles: Set<String>,
        using generator: inout Mulberry32
    ) -> (String, String) {
        let first = pickOne(from: roles, previousRoles: previousRoles, using: &generator)
        let remaining = roles.filter { $0 != first }
        guard !remaining.isEmpty else { return (first, first) }
        let second = pickOne(from: remaining, previousRoles: previousRoles, using: &generator)
        return (first, second)
    }

    private static func shuffled<T>(_ values: [T], using generator: inout Mulberry32) -> [T] {
        var values = values
        guard values.count > 1 else { return values }

        for index in stride(from: values.count - 1, through: 1, by: -1) {
            let randomIndex = Int(generator.nextUnit() * Double(index + 1))
            values.swapAt(index, randomIndex)
        }
        return values
    }
}

private struct Mulberry32 {
    private var state: UInt32

    init(seed: UInt32) {
        state = seed
    }

    mutating func nextUnit() -> Double {
        state &+= 0x6D2B79F5
        var value = state
        value = (value ^ (value >> 15)) &* (value | 1)
        value ^= value &+ ((value ^ (value >> 7)) &* (value | 61))
        value ^= value >> 14
        return Double(value) / 4_294_967_296
    }
}

