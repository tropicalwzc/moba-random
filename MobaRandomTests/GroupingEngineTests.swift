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
}
