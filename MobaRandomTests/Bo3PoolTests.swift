import XCTest
@testable import MobaRandom

final class Bo3PoolTests: XCTestCase {
    private func pool(count: Int, duplicates: [String] = []) -> Bo3Pool {
        let heroes = (1...max(count, 1)).map { "角色\($0)" }
        let text = "测试：\((heroes + duplicates).joined(separator: "、"))"
        return Bo3Pool(text: text)
    }

    func testCategoryOrderAndCrossCategoryDeduplication() {
        let pool = Bo3Pool(text: "射手：A、B、A\n打野：B、C\n辅助：")

        XCTAssertEqual(pool.categories.map(\.name), ["射手", "打野"])
        XCTAssertEqual(pool.categories[0].heroes, ["A", "B"])
        XCTAssertEqual(pool.categories[1].heroes, ["C"])
        XCTAssertEqual(pool.heroRole["A"], "射手")
        XCTAssertEqual(pool.heroRole["C"], "打野")
        XCTAssertEqual(pool.duplicates, ["A", "B"])
        XCTAssertEqual(pool.total, 3)
    }

    func testSharedParserCompatibility() {
        let text = GroupingEngine.defaultPoolText
        let pool = Bo3Pool(text: text)
        let parsed = GroupingEngine.parseRolePool(text)

        XCTAssertEqual(pool.categories.map(\.name), parsed.map(\.name))
        XCTAssertEqual(pool.total, 34)
        XCTAssertEqual(pool.duplicates, [])
        XCTAssertEqual(pool.role(for: "魈"), "打野")
        XCTAssertEqual(pool.role(for: "琴"), "中路")
        XCTAssertEqual(pool.role(for: "赛诺"), "战士")
    }

    func testEmptyAndUnknownLookups() {
        let empty = Bo3Pool(text: "")
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.total, 0)
        XCTAssertNil(empty.role(for: "任意"))

        let pool = Bo3Pool(text: "射手：A、B")
        XCTAssertTrue(pool.contains("A"))
        XCTAssertFalse(pool.contains("C"))
        XCTAssertEqual(pool.allHeroes, ["A", "B"])
    }

    func testHealthThresholds() {
        let eleven = Bo3DraftEngine.poolHealth(for: pool(count: 11))
        XCTAssertFalse(eleven.canStartGame)
        XCTAssertFalse(eleven.canCompleteNoBanGame3)
        XCTAssertFalse(eleven.canCompleteFullGame3)
        XCTAssertTrue(eleven.summary.contains("至少需要 12"))

        let twelve = Bo3DraftEngine.poolHealth(for: pool(count: 12))
        XCTAssertTrue(twelve.canStartGame)
        XCTAssertFalse(twelve.canCompleteNoBanGame3)

        let twentyFour = Bo3DraftEngine.poolHealth(for: pool(count: 24))
        XCTAssertTrue(twentyFour.canStartGame)
        XCTAssertTrue(twentyFour.canCompleteNoBanGame3)
        XCTAssertFalse(twentyFour.canCompleteFullGame3)

        let twentyEight = Bo3DraftEngine.poolHealth(for: pool(count: 28))
        XCTAssertTrue(twentyEight.canCompleteFullGame3)
        XCTAssertTrue(twentyEight.summary.contains("两种赛制都足够"))
    }

    func testHealthSummaryReportsDuplicates() {
        let health = Bo3DraftEngine.poolHealth(for: pool(count: 20, duplicates: ["角色1", "角色2"]))

        XCTAssertEqual(health.duplicates, ["角色1", "角色2"])
        XCTAssertTrue(health.summary.contains("已忽略重复"))
    }
}
