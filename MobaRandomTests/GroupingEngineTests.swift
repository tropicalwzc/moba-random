import XCTest
@testable import MobaRandom

final class GroupingEngineTests: XCTestCase {
    func testDefaultPoolParsingPreservesOrderAndRoleCounts() {
        let categories = GroupingEngine.parseRolePool(GroupingEngine.defaultPoolText)

        XCTAssertEqual(categories.map(\.name), ["射手", "打野", "中路", "战士"])
        XCTAssertEqual(categories.map(\.roles.count), [5, 5, 7, 8])
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

    func testFixedSeedMatchesOriginalJavaScriptAlgorithm() throws {
        let result = try GroupingEngine.generate(
            poolText: GroupingEngine.defaultPoolText,
            lastGameText: "温迪, 胡桃, 钟离, 行秋",
            allowDuplicate: false,
            seed: 1_700_000_000_123
        )

        XCTAssertEqual(result.rolesA, ["甘雨", "胡桃", "希格雯", "班尼特"])
        XCTAssertEqual(result.rolesB, ["公子", "牢大", "龙王", "丝柯克"])
        XCTAssertEqual(result.playersA, [5, 8, 2, 7])
        XCTAssertEqual(result.playersB, [3, 6, 4, 1])
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
}
