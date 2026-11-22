import XCTest

final class Bo3DraftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStartDraftPickHeroAndOpenSheets() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-moba_selected_tab", "bo3",
            "-moba_reset_bo3_series"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["随机"].firstMatch.waitForExistence(timeout: 5))

        let bo3Tab = app.buttons["BO3"].firstMatch
        if bo3Tab.waitForExistence(timeout: 5) {
            bo3Tab.tap()
        }

        let start = app.buttons["开始第 1 局"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let hero = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "温迪，")
        ).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        hero.tap()

        let nextTurn = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "B 队 禁用")
        ).firstMatch
        XCTAssertTrue(nextTurn.waitForExistence(timeout: 5))

        app.buttons["比赛规则"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["比赛规则"].waitForExistence(timeout: 3))
        let rulesShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        rulesShot.name = "BO3 rules light"
        rulesShot.lifetime = .keepAlways
        add(rulesShot)
        app.buttons["完成"].tap()

        app.buttons["BO3 设置"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["BO3 设置"].waitForExistence(timeout: 3))
        app.buttons["取消"].tap()

        app.buttons["系列赛记录"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["系列赛记录"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["暂无前序对局"].waitForExistence(timeout: 3))
        app.buttons["完成"].tap()

        app.buttons["全局重置"].firstMatch.tap()
        let confirmReset = app.sheets.buttons["全局重置"].firstMatch
        XCTAssertTrue(confirmReset.waitForExistence(timeout: 3))
        confirmReset.tap()
        XCTAssertTrue(app.buttons["开始第 1 局"].waitForExistence(timeout: 5))
    }

    func testSwitchToBO3WhileGroupingKeyboardIsOpen() throws {
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "On iPhone the software keyboard covers the tab bar in the test harness."
        )

        let app = XCUIApplication()
        app.launchArguments += [
            "-moba_selected_tab", "grouping",
            "-moba_reset_bo3_series"
        ]
        app.launch()

        let poolEditor = app.textViews["角色池"].firstMatch
        XCTAssertTrue(poolEditor.waitForExistence(timeout: 5))
        poolEditor.tap()
        poolEditor.typeText("a")

        let bo3Tab = app.buttons["BO3"].firstMatch
        XCTAssertTrue(bo3Tab.waitForExistence(timeout: 5))
        bo3Tab.tap()

        let afterSwitch = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterSwitch.name = "after switching to BO3 with keyboard"
        afterSwitch.lifetime = .keepAlways
        add(afterSwitch)

        XCTAssertTrue(app.buttons["开始第 1 局"].waitForExistence(timeout: 10))
    }

    func testBO3SearchWithKeyboardStaysResponsive() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-moba_selected_tab", "bo3",
            "-moba_reset_bo3_series"
        ]
        app.launch()

        let bo3Tab = app.buttons["BO3"].firstMatch
        if bo3Tab.waitForExistence(timeout: 5) {
            bo3Tab.tap()
        }

        let searchButton = app.buttons["搜索角色"].firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5))
        searchButton.tap()

        let searchField = app.textFields["搜索角色"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("温")

        let hero = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "温迪，")
        ).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
    }

    func testIPadLandscapeSmoke() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        addTeardownBlock {
            XCUIDevice.shared.orientation = .portrait
        }

        let app = XCUIApplication()
        app.launchArguments += [
            "-moba_selected_tab", "bo3",
            "-moba_reset_bo3_series"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["随机"].firstMatch.waitForExistence(timeout: 5))

        let bo3Tab = app.buttons["BO3"].firstMatch
        if bo3Tab.waitForExistence(timeout: 5) {
            bo3Tab.tap()
        }

        let start = app.buttons["开始第 1 局"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let hero = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "温迪，")
        ).firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        hero.tap()

        let nextTurn = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "B 队 禁用")
        ).firstMatch
        XCTAssertTrue(nextTurn.waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "iPad landscape BO3"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
