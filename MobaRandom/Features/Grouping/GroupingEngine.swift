import Foundation

struct RoleCategory: Equatable, Sendable {
    let name: String
    let roles: [String]
}

struct CharacterLaneWeights: Codable, Equatable, Sendable {
    let character: String
    var laneWeights: [String: Int]
    let sourceLane: String?

    init(character: String, laneWeights: [String: Int], sourceLane: String? = nil) {
        self.character = character
        self.laneWeights = laneWeights
        self.sourceLane = sourceLane
    }
}

struct RoleWeightConfiguration: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    var characters: [CharacterLaneWeights]

    init(version: Int = currentVersion, characters: [CharacterLaneWeights]) {
        self.version = version
        self.characters = characters
    }

    func weight(for character: String, lane: String) -> Int {
        characters.first(where: { $0.character == character })?.laneWeights[lane] ?? 0
    }

    func isValid(lanes: [String]) -> Bool {
        version == Self.currentVersion && characters.allSatisfy { entry in
            Set(entry.laneWeights.keys).isSubset(of: Set(lanes)) &&
                entry.laneWeights.values.allSatisfy { $0 >= 0 } &&
                lanes.reduce(0) { $0 + (entry.laneWeights[$1] ?? 0) } == 100
        }
    }

    static func reconciled(
        categories: [RoleCategory],
        saved: RoleWeightConfiguration?
    ) -> RoleWeightConfiguration {
        let lanes = categories.map(\.name)
        let laneSet = Set(lanes)
        var characterOrder: [String] = []
        var defaultLane: [String: String] = [:]

        for category in categories {
            for character in category.roles where defaultLane[character] == nil {
                defaultLane[character] = category.name
                characterOrder.append(character)
            }
        }

        var savedByName: [String: CharacterLaneWeights] = [:]
        if let saved, saved.version == currentVersion {
            for entry in saved.characters where savedByName[entry.character] == nil {
                savedByName[entry.character] = entry
            }
        }

        let entries = characterOrder.compactMap { character -> CharacterLaneWeights? in
            guard let fallbackLane = defaultLane[character] else { return nil }
            let fallback = oneHot(character: character, defaultLane: fallbackLane, lanes: lanes)
            guard let old = savedByName[character],
                  old.laneWeights.values.allSatisfy({ $0 >= 0 }) else {
                return fallback
            }
            guard old.sourceLane == nil || old.sourceLane == fallbackLane else {
                return fallback
            }

            var reconciled = Dictionary(uniqueKeysWithValues: lanes.map { ($0, old.laneWeights[$0] ?? 0) })
            let removedWeight = old.laneWeights.reduce(0) { partial, item in
                partial + (laneSet.contains(item.key) ? 0 : item.value)
            }
            reconciled[fallbackLane, default: 0] += removedWeight

            guard reconciled.values.reduce(0, +) == 100 else { return fallback }
            return CharacterLaneWeights(
                character: character,
                laneWeights: reconciled,
                sourceLane: fallbackLane
            )
        }

        return RoleWeightConfiguration(characters: entries)
    }

    static func normalizedToHundred(_ values: [Int]) -> [Int]? {
        guard values.allSatisfy({ $0 >= 0 }) else { return nil }
        let total = values.reduce(0, +)
        guard total > 100 else { return values }

        let scaledProducts = values.map { Int64($0) * 100 }
        let divisor = Int64(total)
        var result = scaledProducts.map { Int($0 / divisor) }
        let remainders = scaledProducts.enumerated().map { (index: $0.offset, remainder: $0.element % divisor) }
            .sorted {
                if $0.remainder == $1.remainder { return $0.index < $1.index }
                return $0.remainder > $1.remainder
            }
        var remaining = 100 - result.reduce(0, +)
        var cursor = 0
        while remaining > 0 {
            result[remainders[cursor].index] += 1
            remaining -= 1
            cursor += 1
        }
        return result
    }

    private static func oneHot(
        character: String,
        defaultLane: String,
        lanes: [String]
    ) -> CharacterLaneWeights {
        CharacterLaneWeights(
            character: character,
            laneWeights: Dictionary(uniqueKeysWithValues: lanes.map { ($0, $0 == defaultLane ? 100 : 0) }),
            sourceLane: defaultLane
        )
    }
}

struct RoleWeightTransferPayload: Codable, Equatable, Sendable {
    let version: Int
    let lanes: [String]
    let characters: [CharacterLaneWeights]

    init(lanes: [String], configuration: RoleWeightConfiguration) {
        version = configuration.version
        self.lanes = lanes
        characters = configuration.characters
    }
}

struct ImportedRoleWeights: Equatable, Sendable {
    let poolText: String
    let configuration: RoleWeightConfiguration
}

enum RoleWeightTransferError: LocalizedError, Equatable {
    case invalidJSON
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "剪切板中没有可识别的权重 JSON。"
        case .invalidConfiguration:
            "JSON 中的分路和角色名称必须唯一且非空，每个角色只能使用非负整数，权重合计必须为 100。"
        }
    }
}

enum RoleWeightTransfer {
    static func exportJSON(
        lanes: [String],
        configuration: RoleWeightConfiguration
    ) throws -> String {
        guard validated(lanes: lanes, characters: configuration.characters) != nil else {
            throw RoleWeightTransferError.invalidConfiguration
        }
        let payload = RoleWeightTransferPayload(lanes: lanes, configuration: configuration)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else {
            throw RoleWeightTransferError.invalidJSON
        }
        return json
    }

    static func importJSON(_ json: String, currentLanes: [String]) throws -> ImportedRoleWeights {
        guard let data = json.data(using: .utf8) else {
            throw RoleWeightTransferError.invalidJSON
        }
        let decoder = JSONDecoder()
        let lanes: [String]
        let characters: [CharacterLaneWeights]
        let version: Int

        if let payload = try? decoder.decode(RoleWeightTransferPayload.self, from: data) {
            lanes = payload.lanes
            characters = payload.characters
            version = payload.version
        } else if let legacy = try? decoder.decode(RoleWeightConfiguration.self, from: data) {
            let current = currentLanes.filter { lane in
                legacy.characters.contains { $0.laneWeights.keys.contains(lane) }
            }
            let known = Set(current)
            let additional = Set(legacy.characters.flatMap { $0.laneWeights.keys })
                .subtracting(known)
                .sorted()
            lanes = current + additional
            characters = legacy.characters
            version = legacy.version
        } else {
            throw RoleWeightTransferError.invalidJSON
        }

        guard version == RoleWeightConfiguration.currentVersion,
              let importedCharacters = validated(lanes: lanes, characters: characters) else {
            throw RoleWeightTransferError.invalidConfiguration
        }

        var grouped = Dictionary(uniqueKeysWithValues: lanes.map { ($0, [String]()) })
        let canonicalCharacters = importedCharacters.map { entry -> CharacterLaneWeights in
            let primaryLane = lanes.max { lhs, rhs in
                let lhsWeight = entry.laneWeights[lhs] ?? 0
                let rhsWeight = entry.laneWeights[rhs] ?? 0
                if lhsWeight == rhsWeight {
                    return lanes.firstIndex(of: lhs)! > lanes.firstIndex(of: rhs)!
                }
                return lhsWeight < rhsWeight
            }!
            grouped[primaryLane, default: []].append(entry.character)
            return CharacterLaneWeights(
                character: entry.character,
                laneWeights: entry.laneWeights,
                sourceLane: primaryLane
            )
        }
        let poolText = lanes.map { lane in
            "\(lane)：\(grouped[lane, default: []].joined(separator: "、"))"
        }.joined(separator: "\n")

        return ImportedRoleWeights(
            poolText: poolText,
            configuration: RoleWeightConfiguration(characters: canonicalCharacters)
        )
    }

    private static func validated(
        lanes: [String],
        characters: [CharacterLaneWeights]
    ) -> [CharacterLaneWeights]? {
        guard !lanes.isEmpty,
              Set(lanes).count == lanes.count,
              lanes.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              !characters.isEmpty,
              Set(characters.map(\.character)).count == characters.count,
              characters.allSatisfy({ !$0.character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return nil
        }
        let laneSet = Set(lanes)
        var validatedCharacters: [CharacterLaneWeights] = []
        for entry in characters {
            guard entry.laneWeights.keys.allSatisfy(laneSet.contains),
                  entry.laneWeights.values.allSatisfy({ $0 >= 0 }) else { return nil }
            let weights = Dictionary(uniqueKeysWithValues: lanes.map { ($0, entry.laneWeights[$0] ?? 0) })
            guard weights.values.reduce(0, +) == 100 else { return nil }
            validatedCharacters.append(CharacterLaneWeights(
                character: entry.character,
                laneWeights: weights,
                sourceLane: entry.sourceLane
            ))
        }
        return validatedCharacters
    }
}

enum BuiltInWeightPresetMigration {
    static let markerKey = "moba_builtin_weight_preset_v2_applied"
    static let resourceName = "default-role-weights-v2"

    static func isPending(in defaults: UserDefaults) -> Bool {
        !defaults.bool(forKey: markerKey)
    }

    static func markApplied(in defaults: UserDefaults) {
        defaults.set(true, forKey: markerKey)
    }

    static func load(
        from bundle: Bundle = .main,
        currentLanes: [String]
    ) throws -> ImportedRoleWeights {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let json = try? String(contentsOf: url, encoding: .utf8) else {
            throw RoleWeightTransferError.invalidJSON
        }
        return try RoleWeightTransfer.importJSON(json, currentLanes: currentLanes)
    }
}

enum ResultTeam: String, Codable, Sendable {
    case a
    case b
}

struct RoleSlot: Hashable, Codable, Sendable {
    let team: ResultTeam
    let index: Int
}

struct GroupingResult: Codable, Equatable, Sendable {
    let seed: Int64
    let playersA: [Int]
    let playersB: [Int]
    let rolesA: [String]
    let rolesB: [String]

    func role(team: ResultTeam, index: Int) -> String? {
        let roles = team == .a ? rolesA : rolesB
        guard roles.indices.contains(index) else { return nil }
        return roles[index]
    }

    func replacingRole(team: ResultTeam, index: Int, with role: String) -> GroupingResult? {
        guard self.role(team: team, index: index) != nil else { return nil }
        var updatedRolesA = rolesA
        var updatedRolesB = rolesB

        if team == .a {
            updatedRolesA[index] = role
        } else {
            updatedRolesB[index] = role
        }

        return GroupingResult(
            seed: seed,
            playersA: playersA,
            playersB: playersB,
            rolesA: updatedRolesA,
            rolesB: updatedRolesB
        )
    }

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

struct GameHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Date
    var result: GroupingResult
    var swappedSlots: Set<RoleSlot>

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        result: GroupingResult,
        swappedSlots: Set<RoleSlot> = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.result = result
        self.swappedSlots = swappedSlots
    }
}

enum GroupingError: LocalizedError, Equatable, Sendable {
    case invalidPool
    case insufficientRoles(category: String)
    case impossibleWeightConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidPool:
            "角色池格式不正确或为空。请确保每行格式为：职业名：角色1、角色2"
        case let .insufficientRoles(category):
            "职业“\(category)”的角色数量不足 2 个。请补充角色，或开启“允许两组使用相同角色”。"
        case .impossibleWeightConfiguration:
            "当前分路权重无法组成完整且不重复的阵容。请调整权重、补充角色，或开启镜像模式。"
        }
    }
}

enum GroupingEngine {
    static let historyLimit = 100
    static let defaultPoolText = """
    射手：温迪、甘雨、宵宫、提纳里、公子、夜兰
    打野：绫华、胡桃、雷神、刻晴、牢大
    中路：希格雯、钟离、神子、龙王、少女、纳西妲、可莉
    战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、迪卢克、洛恩、琴、杜林
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

            guard !name.isEmpty else { continue }

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

    static func previousRolesText(from result: GroupingResult?) -> String {
        guard let result else { return "" }
        return (result.rolesA + result.rolesB).joined(separator: "，")
    }

    static func effectiveWeight(
        character: String,
        lane: String,
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>
    ) -> Double {
        let configured = Double(configuration.weight(for: character, lane: lane)) / 100
        return configured * (previousRoles.contains(character) ? 0.1 : 1.0)
    }

    static func generate(
        poolText: String,
        lastGameText: String,
        allowDuplicate: Bool,
        weightConfiguration: RoleWeightConfiguration? = nil,
        seed: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)
    ) throws -> GroupingResult {
        let categories = parseRolePool(poolText)
        guard !categories.isEmpty else { throw GroupingError.invalidPool }

        let configuration = RoleWeightConfiguration.reconciled(
            categories: categories,
            saved: weightConfiguration
        )

        if !allowDuplicate,
           let invalidCategory = categories.first(where: { category in
               configuration.characters.filter { configuration.weight(for: $0.character, lane: category.name) > 0 }.count < 2
           }) {
            throw GroupingError.insufficientRoles(category: invalidCategory.name)
        }

        let previousRoles = parseLastGameRoles(lastGameText)
        var generator = Mulberry32(seed: UInt32(truncatingIfNeeded: seed))
        let rolesA: [String]
        let rolesB: [String]

        if allowDuplicate {
            guard let assignmentA = assign(
                slots: categories.indices.map { AssignmentSlot(team: .a, laneIndex: $0) },
                categories: categories,
                configuration: configuration,
                previousRoles: previousRoles,
                using: &generator
            ), let assignmentB = assign(
                slots: categories.indices.map { AssignmentSlot(team: .b, laneIndex: $0) },
                categories: categories,
                configuration: configuration,
                previousRoles: previousRoles,
                using: &generator
            ) else {
                throw GroupingError.impossibleWeightConfiguration
            }
            rolesA = orderedRoles(from: assignmentA, team: .a, count: categories.count)
            rolesB = orderedRoles(from: assignmentB, team: .b, count: categories.count)
        } else {
            let slots = categories.indices.flatMap { index in
                [AssignmentSlot(team: .a, laneIndex: index), AssignmentSlot(team: .b, laneIndex: index)]
            }
            guard let assignment = assign(
                slots: slots,
                categories: categories,
                configuration: configuration,
                previousRoles: previousRoles,
                using: &generator
            ) else {
                throw GroupingError.impossibleWeightConfiguration
            }
            rolesA = orderedRoles(from: assignment, team: .a, count: categories.count)
            rolesB = orderedRoles(from: assignment, team: .b, count: categories.count)
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

    static func replacementCandidates(
        for result: GroupingResult,
        team: ResultTeam,
        index: Int,
        poolText: String,
        allowDuplicate: Bool,
        weightConfiguration: RoleWeightConfiguration? = nil
    ) -> [String] {
        let categories = parseRolePool(poolText)
        guard categories.indices.contains(index),
              let currentRole = result.role(team: team, index: index) else {
            return []
        }

        let configuration = RoleWeightConfiguration.reconciled(categories: categories, saved: weightConfiguration)
        let forbidden: Set<String>
        if allowDuplicate {
            let sameTeamRoles = team == .a ? result.rolesA : result.rolesB
            forbidden = Set(sameTeamRoles)
        } else {
            forbidden = Set(result.rolesA + result.rolesB)
        }

        return configuration.characters.compactMap { entry in
            guard entry.character != currentRole,
                  !forbidden.contains(entry.character),
                  configuration.weight(for: entry.character, lane: categories[index].name) > 0 else {
                return nil
            }
            return entry.character
        }
    }

    static func replacementRole(
        for result: GroupingResult,
        team: ResultTeam,
        index: Int,
        poolText: String,
        lastGameText: String,
        allowDuplicate: Bool,
        weightConfiguration: RoleWeightConfiguration? = nil,
        seed: Int64 = Int64(Date().timeIntervalSince1970 * 1_000)
    ) -> String? {
        let categories = parseRolePool(poolText)
        guard categories.indices.contains(index) else { return nil }
        let configuration = RoleWeightConfiguration.reconciled(categories: categories, saved: weightConfiguration)
        let previousRoles = parseLastGameRoles(lastGameText)
        let candidates = replacementCandidates(
            for: result,
            team: team,
            index: index,
            poolText: poolText,
            allowDuplicate: allowDuplicate,
            weightConfiguration: configuration
        )
        var generator = Mulberry32(seed: UInt32(truncatingIfNeeded: seed))
        return pickWeighted(
            from: candidates,
            lane: categories[index].name,
            configuration: configuration,
            previousRoles: previousRoles,
            using: &generator
        )
    }

    static func limitedHistory(_ entries: [GameHistoryEntry]) -> [GameHistoryEntry] {
        Array(entries.prefix(historyLimit))
    }

    private struct AssignmentSlot: Hashable {
        let team: ResultTeam
        let laneIndex: Int
    }

    private static func orderedRoles(
        from assignment: [AssignmentSlot: String],
        team: ResultTeam,
        count: Int
    ) -> [String] {
        (0..<count).compactMap { assignment[AssignmentSlot(team: team, laneIndex: $0)] }
    }

    private static func assign(
        slots: [AssignmentSlot],
        categories: [RoleCategory],
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>,
        using generator: inout Mulberry32
    ) -> [AssignmentSlot: String]? {
        func search(
            remaining: [AssignmentSlot],
            used: Set<String>,
            assignment: [AssignmentSlot: String],
            generator: inout Mulberry32
        ) -> [AssignmentSlot: String]? {
            guard !remaining.isEmpty else { return assignment }

            let rankedSlots = remaining.enumerated().map { offset, slot in
                let lane = categories[slot.laneIndex].name
                let count = configuration.characters.reduce(0) { partial, entry in
                    partial + (!used.contains(entry.character) && configuration.weight(for: entry.character, lane: lane) > 0 ? 1 : 0)
                }
                return (offset: offset, slot: slot, candidateCount: count)
            }
            guard let selected = rankedSlots.min(by: {
                if $0.candidateCount == $1.candidateCount { return $0.offset < $1.offset }
                return $0.candidateCount < $1.candidateCount
            }), selected.candidateCount > 0 else { return nil }

            let lane = categories[selected.slot.laneIndex].name
            let candidates = configuration.characters.map(\.character).filter {
                !used.contains($0) && configuration.weight(for: $0, lane: lane) > 0
            }
            let orderedCandidates = weightedOrder(
                candidates,
                lane: lane,
                configuration: configuration,
                previousRoles: previousRoles,
                using: &generator
            )
            var nextRemaining = remaining
            nextRemaining.remove(at: selected.offset)

            for character in orderedCandidates {
                var nextAssignment = assignment
                nextAssignment[selected.slot] = character
                if let result = search(
                    remaining: nextRemaining,
                    used: used.union([character]),
                    assignment: nextAssignment,
                    generator: &generator
                ) {
                    return result
                }
            }
            return nil
        }

        return search(remaining: slots, used: [], assignment: [:], generator: &generator)
    }

    private static func weightedOrder(
        _ characters: [String],
        lane: String,
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>,
        using generator: inout Mulberry32
    ) -> [String] {
        var remaining = characters
        var result: [String] = []
        while !remaining.isEmpty {
            guard let next = pickWeighted(
                from: remaining,
                lane: lane,
                configuration: configuration,
                previousRoles: previousRoles,
                using: &generator
            ) else { break }
            result.append(next)
            remaining.removeAll { $0 == next }
        }
        return result
    }

    private static func pickWeighted(
        from characters: [String],
        lane: String,
        configuration: RoleWeightConfiguration,
        previousRoles: Set<String>,
        using generator: inout Mulberry32
    ) -> String? {
        let weighted = characters.map { character in
            (
                character,
                effectiveWeight(
                    character: character,
                    lane: lane,
                    configuration: configuration,
                    previousRoles: previousRoles
                )
            )
        }.filter { $0.1 > 0 }
        guard !weighted.isEmpty else { return nil }

        var randomWeight = generator.nextUnit() * weighted.reduce(0) { $0 + $1.1 }
        for item in weighted {
            randomWeight -= item.1
            if randomWeight <= 0 { return item.0 }
        }
        return weighted.last?.0
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
