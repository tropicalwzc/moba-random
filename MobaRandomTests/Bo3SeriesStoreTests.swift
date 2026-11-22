import XCTest
@testable import MobaRandom

final class Bo3SeriesStoreTests: XCTestCase {
    private func makePool(_ count: Int) -> Bo3Pool {
        let heroes = (1...max(count, 1)).map { "角色\($0)" }
        return Bo3Pool(text: "测试：\(heroes.joined(separator: "、"))")
    }

    @MainActor
    private func makeStore() throws -> (store: Bo3SeriesStore, defaults: UserDefaults, suiteName: String) {
        let suiteName = "Bo3SeriesStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (Bo3SeriesStore(defaults: defaults), defaults, suiteName)
    }

    @MainActor
    private func fill(_ store: Bo3SeriesStore, heroes: [String]) throws {
        for hero in heroes {
            try store.choose(hero: hero, role: "测试")
        }
    }

    @MainActor
    func testEmptyStoreLoadsNoSeries() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(store.series.currentGame, 0)
        XCTAssertTrue(store.series.games.allSatisfy { !$0.started && $0.actions.isEmpty })
        XCTAssertNil(store.series.seats)
        XCTAssertFalse(store.hasProgress)
    }

    @MainActor
    func testMutationsPersistAcrossStoreInstances() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try store.startGame(pool: makePool(30))
        try store.choose(hero: "角色1", role: "测试")
        XCTAssertEqual(store.series.games[0].actions.count, 1)

        let reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertEqual(reloaded.series.currentGame, 1)
        XCTAssertEqual(reloaded.series.games[0].actions.count, 1)
        XCTAssertEqual(reloaded.series.games[0].actions[0].hero, "角色1")
        XCTAssertTrue(Bo3DraftEngine.isValidSeats(reloaded.series.seats))
    }

    @MainActor
    func testWinnerAndUndoPersist() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try store.startGame(pool: makePool(30))
        try fill(store, heroes: (1...12).map { "角色\($0)" })
        try store.setWinner(.a)

        var reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertEqual(reloaded.series.games[0].winner, .a)

        XCTAssertTrue(reloaded.undo())
        reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertNil(reloaded.series.games[0].winner)
        XCTAssertEqual(reloaded.series.games[0].actions.count, 12)
    }

    @MainActor
    func testResetPersistsAndPreservesSettings() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        store.updateTeamNames(Bo3TeamNames(a: "红队", b: "紫队"))
        store.updateNoBanGame3(false)
        try store.startGame(pool: makePool(30))
        try store.choose(hero: "角色1", role: "测试")
        store.reset()

        let reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertEqual(reloaded.series.currentGame, 0)
        XCTAssertNil(reloaded.series.seats)
        XCTAssertEqual(reloaded.series.teamNames.a, "红队")
        XCTAssertEqual(reloaded.series.teamNames.b, "紫队")
        XCTAssertFalse(reloaded.series.noBanGame3)
    }

    @MainActor
    func testCorruptPayloadFallsBackToAnEmptySeries() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        _ = store

        defaults.set(Data("not-json".utf8), forKey: Bo3SeriesStore.storageKey)

        let reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertEqual(reloaded.series.currentGame, 0)
        XCTAssertTrue(reloaded.series.games.allSatisfy { !$0.started && $0.actions.isEmpty })
    }

    @MainActor
    func testFutureGamesAreResetOnLoad() throws {
        let (_, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var series = Bo3Series(currentGame: 1)
        series.seats = Bo3Seats(a: [1, 2, 3, 4], b: [5, 6, 7, 8])
        series.games[0] = Bo3Game(
            started: true,
            actions: [Bo3Action(team: .a, type: .ban, hero: "甲", role: "")]
        )
        series.games[1] = Bo3Game(
            started: true,
            actions: [Bo3Action(team: .b, type: .pick, hero: "乙", role: "")]
        )
        defaults.set(try JSONEncoder().encode(series), forKey: Bo3SeriesStore.storageKey)

        let reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertEqual(reloaded.series.games[0].actions.count, 1)
        XCTAssertFalse(reloaded.series.games[1].started)
        XCTAssertTrue(reloaded.series.games[1].actions.isEmpty)
    }

    @MainActor
    func testInvalidSeatsAreRepairedOnLoad() throws {
        let (_, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var series = Bo3Series(currentGame: 1)
        series.seats = Bo3Seats(a: [1, 1, 2, 3], b: [4, 5, 6, 7])
        defaults.set(try JSONEncoder().encode(series), forKey: Bo3SeriesStore.storageKey)

        let reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertTrue(Bo3DraftEngine.isValidSeats(reloaded.series.seats))
    }

    @MainActor
    func testEngineErrorsDoNotMutateTheStore() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertThrowsError(try store.startGame(pool: makePool(11))) { error in
            XCTAssertEqual(
                error as? Bo3EngineError,
                .poolTooSmall(minimum: 12, actual: 11)
            )
        }
        XCTAssertEqual(store.series.currentGame, 0)

        XCTAssertThrowsError(try store.choose(hero: "角色1", role: "测试")) { error in
            XCTAssertEqual(error as? Bo3EngineError, .noActiveGame)
        }
        XCTAssertTrue(store.series.games.allSatisfy { $0.actions.isEmpty })
    }

    @MainActor
    func testTeamNamesAreNormalizedBeforeSaving() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        store.updateTeamNames(
            Bo3TeamNames(a: "   ", b: String(repeating: "长", count: 22))
        )

        let reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertEqual(reloaded.series.teamNames.a, "A 队")
        XCTAssertEqual(reloaded.series.teamNames.b.count, 16)
    }

    @MainActor
    func testNoBanSettingPersists() throws {
        let (store, defaults, suiteName) = try makeStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        store.updateNoBanGame3(false)

        let reloaded = Bo3SeriesStore(defaults: defaults)
        XCTAssertFalse(reloaded.series.noBanGame3)
    }
}
