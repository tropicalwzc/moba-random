import XCTest
@testable import MobaRandom

final class GroupingEngineTests: XCTestCase {
    private let legacyWebPoolText = """
    射手：温迪、甘雨、宵宫、提纳里、公子、夜兰
    打野：绫华、胡桃、雷神、刻晴、牢大
    中路：希格雯、钟离、神子、龙王、少女、纳西妲、可莉
    战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、迪卢克、洛恩、琴、杜林
    """

    func testDefaultPoolParsingPreservesOrderAndRoleCounts() {
        let categories = GroupingEngine.parseRolePool(GroupingEngine.defaultPoolText)

        XCTAssertEqual(categories.map(\.name), ["射手", "打野", "中路", "战士"])
        XCTAssertEqual(categories.map(\.roles.count), [7, 6, 8, 13])
        XCTAssertTrue(categories[0].roles.contains("赛索斯"))
        XCTAssertTrue(categories[1].roles.contains("魈"))
        XCTAssertTrue(categories[2].roles.contains("琴"))
        XCTAssertTrue(categories[2].roles.contains("八重"))
        XCTAssertFalse(categories[2].roles.contains("神子"))
        XCTAssertTrue(categories[3].roles.contains("杜林"))
        XCTAssertTrue(categories[3].roles.contains("法尔加"))
        XCTAssertTrue(categories[3].roles.contains("克洛林德"))
        XCTAssertTrue(categories[3].roles.contains("赛诺"))
    }

    func testParserSupportsAllWebSeparatorsAndCustomCategories() {
        let categories = GroupingEngine.parseRolePool(
            "辅助：角色甲 角色乙、角色丙,角色丁，角色戊\n游走: 角色己 角色庚"
        )

        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].name, "辅助")
        XCTAssertEqual(categories[0].roles, ["角色甲", "角色乙", "角色丙", "角色丁", "角色戊"])
        XCTAssertEqual(categories[1].name, "游走")
    }

    func testParserKeepsCanonicalEmptyLaneFromImportedWeights() {
        let categories = GroupingEngine.parseRolePool("射手：A、B\n中路：")

        XCTAssertEqual(categories.map(\.name), ["射手", "中路"])
        XCTAssertEqual(categories.map(\.roles), [["A", "B"], []])
    }

    func testFixedSeedMatchesWeightedCrossClientAlgorithm() throws {
        let result = try GroupingEngine.generate(
            poolText: legacyWebPoolText,
            lastGameText: "温迪, 胡桃, 钟离, 行秋",
            allowDuplicate: false,
            seed: 1_700_000_000_123
        )

        XCTAssertEqual(result.rolesA, ["提纳里", "绫华", "神子", "女仆"])
        XCTAssertEqual(result.rolesB, ["公子", "胡桃", "纳西妲", "点刀"])
        XCTAssertEqual(result.playersA, [8, 2, 1, 6])
        XCTAssertEqual(result.playersB, [7, 4, 5, 3])
    }

    func testDefaultPoolProducesACompleteDeterministicAssignment() throws {
        let result = try GroupingEngine.generate(
            poolText: GroupingEngine.defaultPoolText,
            lastGameText: "",
            allowDuplicate: false,
            seed: 1_700_000_000_123
        )

        XCTAssertEqual(result.rolesA.count, 4)
        XCTAssertEqual(result.rolesB.count, 4)
        XCTAssertEqual(Set(result.rolesA + result.rolesB).count, 8)
    }

    func testNonMirrorModeRejectsSingleRoleCategory() {
        XCTAssertThrowsError(
            try GroupingEngine.generate(
                poolText: "射手：温迪",
                lastGameText: "",
                allowDuplicate: false,
                seed: 1
            )
        ) { error in
            XCTAssertEqual(error as? GroupingError, .insufficientRoles(category: "射手"))
        }
    }

    func testMirrorModeAcceptsSingleRoleCategory() throws {
        let result = try GroupingEngine.generate(
            poolText: "射手：温迪",
            lastGameText: "",
            allowDuplicate: true,
            seed: 1
        )

        XCTAssertEqual(result.rolesA, ["温迪"])
        XCTAssertEqual(result.rolesB, ["温迪"])
        XCTAssertEqual(Set(result.playersA + result.playersB), [1, 2])
    }

    func testReplacementCandidatesStayInSameCategoryAndExcludeCurrentRole() throws {
        let result = try GroupingEngine.generate(
            poolText: "射手：A、B、C、D\n打野：E、F",
            lastGameText: "",
            allowDuplicate: true,
            seed: 10
        )
        let currentRole = try XCTUnwrap(result.role(team: .a, index: 0))

        let candidates = GroupingEngine.replacementCandidates(
            for: result,
            team: .a,
            index: 0,
            poolText: "射手：A、B、C、D\n打野：E、F",
            allowDuplicate: true
        )

        XCTAssertEqual(Set(candidates), Set(["A", "B", "C", "D"]).subtracting([currentRole]))
    }

    func testReplacementCandidatesPreserveNonMirrorUniqueness() throws {
        let pool = "射手：A、B、C、D"
        let result = try GroupingEngine.generate(
            poolText: pool,
            lastGameText: "",
            allowDuplicate: false,
            seed: 10
        )
        let currentRole = try XCTUnwrap(result.role(team: .a, index: 0))
        let opposingRole = try XCTUnwrap(result.role(team: .b, index: 0))

        let candidates = GroupingEngine.replacementCandidates(
            for: result,
            team: .a,
            index: 0,
            poolText: pool,
            allowDuplicate: false
        )

        XCTAssertFalse(candidates.contains(currentRole))
        XCTAssertFalse(candidates.contains(opposingRole))
        XCTAssertEqual(candidates.count, 2)
    }

    func testReplacingRoleOnlyChangesRequestedSlot() throws {
        let original = try GroupingEngine.generate(
            poolText: "射手：A、B、C\n打野：D、E、F",
            lastGameText: "",
            allowDuplicate: false,
            seed: 10
        )

        let updated = try XCTUnwrap(original.replacingRole(team: .b, index: 1, with: "F"))

        XCTAssertEqual(updated.rolesA, original.rolesA)
        XCTAssertEqual(updated.rolesB[0], original.rolesB[0])
        XCTAssertEqual(updated.rolesB[1], "F")
        XCTAssertEqual(updated.playersA, original.playersA)
        XCTAssertEqual(updated.playersB, original.playersB)
    }

    func testHistoryIsLimitedToNewestOneHundredEntries() throws {
        let result = try GroupingEngine.generate(
            poolText: "射手：A、B",
            lastGameText: "",
            allowDuplicate: false,
            seed: 10
        )
        let entries = (0..<105).map { index in
            GameHistoryEntry(
                createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                result: result
            )
        }

        let limited = GroupingEngine.limitedHistory(entries)

        XCTAssertEqual(limited.count, 100)
        XCTAssertEqual(limited.first?.createdAt, entries.first?.createdAt)
        XCTAssertEqual(limited.last?.createdAt, entries[99].createdAt)
    }

    func testDefaultWeightsUseFirstListedLaneAndDeduplicateCharacters() {
        let categories = GroupingEngine.parseRolePool("射手：A、B\n中路：A、C")
        let configuration = RoleWeightConfiguration.reconciled(categories: categories, saved: nil)

        XCTAssertEqual(configuration.characters.map(\.character), ["A", "B", "C"])
        XCTAssertEqual(configuration.characters[0].laneWeights, ["射手": 100, "中路": 0])
        XCTAssertEqual(configuration.characters[2].laneWeights, ["射手": 0, "中路": 100])
        XCTAssertTrue(configuration.isValid(lanes: ["射手", "中路"]))
    }

    func testLargestRemainderNormalization() {
        XCTAssertEqual(RoleWeightConfiguration.normalizedToHundred([90, 20, 0, 0]), [82, 18, 0, 0])
        XCTAssertEqual(RoleWeightConfiguration.normalizedToHundred([120, 0, 0, 0]), [100, 0, 0, 0])
        XCTAssertEqual(RoleWeightConfiguration.normalizedToHundred([101, 101, 101]), [34, 33, 33])
        XCTAssertEqual(RoleWeightConfiguration.normalizedToHundred([1, 1, 1]), [1, 1, 1])
        XCTAssertNil(RoleWeightConfiguration.normalizedToHundred([-1, 101]))
    }

    func testReconciliationTransfersRemovedLaneWeightAndAddsDefaults() throws {
        let saved = RoleWeightConfiguration(characters: [
            CharacterLaneWeights(character: "A", laneWeights: ["射手": 80, "中路": 20]),
            CharacterLaneWeights(character: "B", laneWeights: ["射手": 100, "中路": 0]),
            CharacterLaneWeights(character: "C", laneWeights: ["射手": 0, "中路": 100]),
        ])
        let categories = GroupingEngine.parseRolePool("射手：A、D\n打野：C")
        let result = RoleWeightConfiguration.reconciled(categories: categories, saved: saved)

        XCTAssertEqual(result.characters.map(\.character), ["A", "D", "C"])
        XCTAssertEqual(result.characters.first { $0.character == "A" }?.laneWeights, ["射手": 100, "打野": 0])
        XCTAssertEqual(result.characters.first { $0.character == "C" }?.laneWeights, ["射手": 0, "打野": 100])
        XCTAssertEqual(result.characters.first { $0.character == "D" }?.laneWeights, ["射手": 100, "打野": 0])
        XCTAssertNil(result.characters.first { $0.character == "B" })
    }

    func testInvalidSavedWeightsResetToOneHotDefault() {
        let saved = RoleWeightConfiguration(characters: [
            CharacterLaneWeights(character: "A", laneWeights: ["射手": -1, "中路": 101]),
        ])
        let categories = GroupingEngine.parseRolePool("射手：A\n中路：B")
        let result = RoleWeightConfiguration.reconciled(categories: categories, saved: saved)

        XCTAssertEqual(result.characters.first?.laneWeights, ["射手": 100, "中路": 0])
    }

    func testMovingCharacterToAnotherLaneResetsItsWeights() {
        let saved = RoleWeightConfiguration(characters: [
            CharacterLaneWeights(
                character: "A",
                laneWeights: ["射手": 80, "中路": 20],
                sourceLane: "射手"
            ),
            CharacterLaneWeights(
                character: "B",
                laneWeights: ["射手": 70, "中路": 30],
                sourceLane: "射手"
            ),
        ])

        let result = RoleWeightConfiguration.reconciled(
            categories: GroupingEngine.parseRolePool("射手：B\n中路：A"),
            saved: saved
        )

        XCTAssertEqual(result.characters.first { $0.character == "A" }?.laneWeights, ["射手": 0, "中路": 100])
        XCTAssertEqual(result.characters.first { $0.character == "A" }?.sourceLane, "中路")
        XCTAssertEqual(result.characters.first { $0.character == "B" }?.laneWeights, ["射手": 70, "中路": 30])
    }

    func testLegacyWeightsGainSourceLaneWithoutBeingReset() {
        let saved = RoleWeightConfiguration(characters: [
            CharacterLaneWeights(character: "A", laneWeights: ["射手": 35, "中路": 65]),
        ])

        let result = RoleWeightConfiguration.reconciled(
            categories: GroupingEngine.parseRolePool("射手：A\n中路：B"),
            saved: saved
        )

        XCTAssertEqual(result.characters.first?.laneWeights, ["射手": 35, "中路": 65])
        XCTAssertEqual(result.characters.first?.sourceLane, "射手")
    }

    func testWeightJSONRoundTripRebuildsCanonicalHomepagePool() throws {
        let configuration = RoleWeightConfiguration(characters: [
            CharacterLaneWeights(character: "角色A", laneWeights: ["射手": 80, "中路": 20], sourceLane: "射手"),
            CharacterLaneWeights(character: "角色B", laneWeights: ["射手": 10, "中路": 90], sourceLane: "中路"),
            CharacterLaneWeights(character: "角色C", laneWeights: ["射手": 100, "中路": 0], sourceLane: "射手"),
        ])

        let json = try RoleWeightTransfer.exportJSON(lanes: ["射手", "中路"], configuration: configuration)
        let imported = try RoleWeightTransfer.importJSON(json, currentLanes: [])

        XCTAssertEqual(imported.poolText, "射手：角色A、角色C\n中路：角色B")
        XCTAssertEqual(imported.configuration.characters, configuration.characters)
    }

    func testWeightJSONImportUsesLaneOrderForTiesAndPreservesEmptyLane() throws {
        let configuration = RoleWeightConfiguration(characters: [
            CharacterLaneWeights(character: "A", laneWeights: ["射手": 50, "中路": 50]),
        ])
        let json = try RoleWeightTransfer.exportJSON(lanes: ["射手", "中路"], configuration: configuration)

        let imported = try RoleWeightTransfer.importJSON(json, currentLanes: [])

        XCTAssertEqual(imported.poolText, "射手：A\n中路：")
        XCTAssertEqual(imported.configuration.characters.first?.sourceLane, "射手")
        XCTAssertEqual(GroupingEngine.parseRolePool(imported.poolText).map(\.name), ["射手", "中路"])
    }

    func testLegacyWeightJSONWithoutLanesImportsUsingCurrentLaneOrder() throws {
        let json = #"{"version":1,"characters":[{"character":"A","laneWeights":{"射手":80,"中路":20}}]}"#

        let imported = try RoleWeightTransfer.importJSON(json, currentLanes: ["射手", "中路"])

        XCTAssertEqual(imported.poolText, "射手：A\n中路：")
        XCTAssertEqual(imported.configuration.characters.first?.laneWeights, ["射手": 80, "中路": 20])
    }

    func testWeightJSONRejectsInvalidTotalsWithoutPartialImport() {
        let json = #"{"version":1,"lanes":["射手","中路"],"characters":[{"character":"A","laneWeights":{"射手":80,"中路":30}}]}"#

        XCTAssertThrowsError(try RoleWeightTransfer.importJSON(json, currentLanes: [])) { error in
            XCTAssertEqual(error as? RoleWeightTransferError, .invalidConfiguration)
        }
    }

    func testBundledWeightPresetIsValidAndBuildsExpectedHomepagePool() throws {
        let imported = try BuiltInWeightPresetMigration.load(
            from: Bundle.main,
            currentLanes: ["射手", "打野", "中路", "战士"]
        )

        XCTAssertEqual(imported.configuration.characters.count, 34)
        XCTAssertEqual(imported.poolText, GroupingEngine.defaultPoolText)
        let character = imported.configuration.characters.first { $0.character == "温迪" }
        XCTAssertEqual(character?.laneWeights, ["射手": 80, "打野": 0, "中路": 20, "战士": 0])
        XCTAssertEqual(character?.sourceLane, "射手")

        let xiao = imported.configuration.characters.first { $0.character == "魈" }
        XCTAssertEqual(xiao?.laneWeights, ["射手": 0, "打野": 100, "中路": 0, "战士": 0])
        XCTAssertEqual(xiao?.sourceLane, "打野")

        let qin = imported.configuration.characters.first { $0.character == "琴" }
        XCTAssertEqual(qin?.laneWeights, ["射手": 0, "打野": 0, "中路": 100, "战士": 0])
        XCTAssertEqual(qin?.sourceLane, "中路")

        for name in ["杜林", "法尔加", "克洛林德", "赛诺"] {
            let added = imported.configuration.characters.first { $0.character == name }
            XCTAssertEqual(added?.laneWeights, ["射手": 0, "打野": 0, "中路": 0, "战士": 100])
            XCTAssertEqual(added?.sourceLane, "战士")
        }
    }

    func testBundledPresetAndStaticDefaultCannotDrift() throws {
        let imported = try BuiltInWeightPresetMigration.load(
            from: Bundle.main,
            currentLanes: ["射手", "打野", "中路", "战士"]
        )

        XCTAssertEqual(imported.poolText, GroupingEngine.defaultPoolText)
    }

    func testBundledWeightPresetMigrationMarkerOnlyAllowsOneApplication() throws {
        let suiteName = "BuiltInWeightPresetMigrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: "moba_builtin_weight_preset_v1_applied")
        XCTAssertTrue(BuiltInWeightPresetMigration.isPending(in: defaults))
        BuiltInWeightPresetMigration.markApplied(in: defaults)
        XCTAssertFalse(BuiltInWeightPresetMigration.isPending(in: defaults))
    }

    func testConfiguredAndPreviousGameWeightsCompose() {
        let configuration = RoleWeightConfiguration(characters: [
            CharacterLaneWeights(character: "A", laneWeights: ["射手": 80, "中路": 20]),
        ])

        XCTAssertEqual(
            GroupingEngine.effectiveWeight(
                character: "A",
                lane: "射手",
                configuration: configuration,
                previousRoles: ["A"]
            ),
            0.08,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            GroupingEngine.effectiveWeight(
                character: "A",
                lane: "中路",
                configuration: configuration,
                previousRoles: []
            ),
            0.2,
            accuracy: 0.000_001
        )
    }

    func testPreviousRolesTextUsesBothTeamsAndEmptyInitialState() {
        XCTAssertEqual(GroupingEngine.previousRolesText(from: nil), "")

        let result = GroupingResult(
            seed: 1,
            playersA: [1, 2],
            playersB: [3, 4],
            rolesA: ["A", "B"],
            rolesB: ["C", "D"]
        )
        let text = GroupingEngine.previousRolesText(from: result)

        XCTAssertEqual(text, "A，B，C，D")
        XCTAssertEqual(GroupingEngine.parseLastGameRoles(text), Set(["A", "B", "C", "D"]))
    }

    func testNormalModeKeepsGlobalCharacterUniqueness() throws {
        let pool = "射手：A、B、C、D\n中路：A、B、C、D"
        let configuration = RoleWeightConfiguration(characters: ["A", "B", "C", "D"].map {
            CharacterLaneWeights(character: $0, laneWeights: ["射手": 50, "中路": 50])
        })
        let result = try GroupingEngine.generate(
            poolText: pool,
            lastGameText: "",
            allowDuplicate: false,
            weightConfiguration: configuration,
            seed: 77
        )

        XCTAssertEqual(Set(result.rolesA + result.rolesB).count, 4)
    }

    func testMirrorModeAllowsCrossTeamReuseButNotWithinTeam() throws {
        let pool = "射手：A、B\n中路：A、B"
        let configuration = RoleWeightConfiguration(characters: ["A", "B"].map {
            CharacterLaneWeights(character: $0, laneWeights: ["射手": 50, "中路": 50])
        })
        let result = try GroupingEngine.generate(
            poolText: pool,
            lastGameText: "",
            allowDuplicate: true,
            weightConfiguration: configuration,
            seed: 91
        )

        XCTAssertEqual(Set(result.rolesA).count, 2)
        XCTAssertEqual(Set(result.rolesB).count, 2)
        XCTAssertFalse(Set(result.rolesA).isDisjoint(with: Set(result.rolesB)))
    }

    func testImpossibleGlobalAssignmentThrowsWeightConfigurationError() {
        let pool = "射手：A、B\n中路：A、B"
        let configuration = RoleWeightConfiguration(characters: ["A", "B"].map {
            CharacterLaneWeights(character: $0, laneWeights: ["射手": 50, "中路": 50])
        })

        XCTAssertThrowsError(
            try GroupingEngine.generate(
                poolText: pool,
                lastGameText: "",
                allowDuplicate: false,
                weightConfiguration: configuration,
                seed: 1
            )
        ) { error in
            XCTAssertEqual(error as? GroupingError, .impossibleWeightConfiguration)
        }
    }
}
