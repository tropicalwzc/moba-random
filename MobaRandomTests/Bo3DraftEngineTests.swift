import XCTest
@testable import MobaRandom

final class Bo3DraftEngineTests: XCTestCase {
    private func makePool(_ count: Int) -> Bo3Pool {
        let heroes = (1...max(count, 1)).map { "角色\($0)" }
        return Bo3Pool(text: "测试：\(heroes.joined(separator: "、"))")
    }

    private func startedSeries(pool: Bo3Pool, noBanGame3: Bool = true) throws -> Bo3Series {
        var series = Bo3Series(noBanGame3: noBanGame3)
        try Bo3DraftEngine.startGame(in: &series, pool: pool)
        return series
    }

    private func fillActiveGame(_ series: inout Bo3Series, heroes: [String]) throws {
        for hero in heroes {
            try Bo3DraftEngine.choose(hero: hero, role: "测试", in: &series)
        }
    }

    private func completeActiveGame(
        _ series: inout Bo3Series,
        startingAt index: Int,
        winner: Bo3Team
    ) throws {
        let heroes = (index..<(index + 12)).map { "角色\($0)" }
        try fillActiveGame(&series, heroes: heroes)
        try Bo3DraftEngine.setWinner(winner, in: &series)
    }

    func testStepSequenceMatchesTheReference() {
        let expected: [(Bo3Team, Bo3ActionType)] = [
            (.a, .ban), (.b, .ban),
            (.a, .pick), (.b, .pick), (.b, .pick), (.a, .pick),
            (.a, .ban), (.b, .ban),
            (.b, .pick), (.a, .pick), (.a, .pick), (.b, .pick),
        ]

        XCTAssertEqual(
            Bo3DraftEngine.stepSequence,
            expected.map { Bo3Step(team: $0.0, type: $0.1) }
        )
        XCTAssertEqual(Bo3DraftEngine.stepSequence.count, 12)
    }

    func testGame3NoBanSequenceIsThePickOnlyFilter() {
        XCTAssertEqual(
            Bo3DraftEngine.game3NoBanSequence,
            Bo3DraftEngine.stepSequence.filter { $0.type == .pick }
        )
        XCTAssertEqual(Bo3DraftEngine.game3NoBanSequence.count, 8)
    }

    func testGame2MirrorsEveryTeamAssignment() {
        XCTAssertEqual(Bo3DraftEngine.game2StepSequence.count, 12)
        XCTAssertEqual(
            Bo3DraftEngine.game2StepSequence.map(\.type),
            Bo3DraftEngine.stepSequence.map(\.type)
        )

        for (game1, game2) in zip(
            Bo3DraftEngine.stepSequence,
            Bo3DraftEngine.game2StepSequence
        ) {
            XCTAssertNotEqual(game1.team, game2.team)
            XCTAssertEqual(game1.type, game2.type)
        }
    }

    func testSequenceResolutionUsesStartedGameThreeFlag() {
        var series = Bo3Series(noBanGame3: true)
        series.currentGame = 3
        series.games[2] = Bo3Game(started: false, noBan: true)
        XCTAssertTrue(Bo3DraftEngine.usesNoBan(for: 3, in: series))
        XCTAssertEqual(Bo3DraftEngine.sequence(for: 3, in: series).count, 8)

        series.games[2] = Bo3Game(started: true, noBan: false)
        XCTAssertFalse(Bo3DraftEngine.usesNoBan(for: 3, in: series))
        XCTAssertEqual(Bo3DraftEngine.sequence(for: 3, in: series).count, 12)

        series.noBanGame3 = false
        series.games[2] = Bo3Game(started: false, noBan: false)
        XCTAssertEqual(Bo3DraftEngine.sequence(for: 3, in: series).count, 12)
        XCTAssertEqual(Bo3DraftEngine.sequence(for: 1, in: series), Bo3DraftEngine.stepSequence)
        XCTAssertEqual(Bo3DraftEngine.sequence(for: 2, in: series), Bo3DraftEngine.game2StepSequence)
        XCTAssertEqual(Bo3DraftEngine.sequence(for: 2, in: series).first?.team, .b)
        XCTAssertEqual(Bo3DraftEngine.sequence(for: 2, in: series).last?.team, .a)
    }

    func testAvailabilitySeparatesCurrentLocksFromPriorPicksAndBans() {
        var series = Bo3Series()
        series.currentGame = 2
        series.games[0] = Bo3Game(
            started: true,
            actions: [
                Bo3Action(team: .a, type: .ban, hero: "甘雨", role: "射手"),
                Bo3Action(team: .b, type: .ban, hero: "刻晴", role: "打野"),
                Bo3Action(team: .a, type: .pick, hero: "温迪", role: "射手"),
            ],
            winner: .a
        )
        series.games[1] = Bo3Game(
            started: true,
            actions: [
                Bo3Action(team: .b, type: .pick, hero: "胡桃", role: "打野"),
            ]
        )

        XCTAssertEqual(
            Bo3DraftEngine.availability(of: "温迪", in: series),
            .globalPick(game: 1, action: series.games[0].actions[2])
        )
        XCTAssertEqual(Bo3DraftEngine.availability(of: "甘雨", in: series), .available)
        XCTAssertEqual(Bo3DraftEngine.availability(of: "胡桃", in: series), .currentGame(series.games[1].actions[0]))
        XCTAssertEqual(Bo3DraftEngine.availability(of: "未知角色", in: series), .available)

        let map = Bo3DraftEngine.availabilityMap(for: ["温迪", "甘雨", "胡桃"], in: series)
        XCTAssertEqual(map.count, 3)
        XCTAssertFalse(map["温迪"]?.isAvailable ?? true)
    }

    func testPickedHeroesIgnoreBansAndRespectTheGameBoundary() {
        var series = Bo3Series()
        series.currentGame = 2
        series.games[0] = Bo3Game(
            started: true,
            actions: [
                Bo3Action(team: .a, type: .ban, hero: "甲", role: ""),
                Bo3Action(team: .a, type: .pick, hero: "乙", role: ""),
            ]
        )
        series.games[1] = Bo3Game(
            started: true,
            actions: [
                Bo3Action(team: .b, type: .pick, hero: "丙", role: ""),
            ]
        )

        XCTAssertEqual(Bo3DraftEngine.pickedHeroes(in: series, throughGameNumber: 1), ["乙"])
        XCTAssertEqual(Bo3DraftEngine.pickedHeroes(in: series, throughGameNumber: 2), ["乙", "丙"])
        XCTAssertEqual(Bo3DraftEngine.currentGameHeroes(in: series), ["丙"])
    }

    func testChooseRejectsDuplicatesAndAdvancesTheSequence() throws {
        var series = try startedSeries(pool: makePool(20))

        try Bo3DraftEngine.choose(hero: "角色1", role: "测试", in: &series)
        XCTAssertEqual(series.games[0].actions.count, 1)
        XCTAssertEqual(series.games[0].actions[0].team, .a)
        XCTAssertEqual(series.games[0].actions[0].type, .ban)

        XCTAssertThrowsError(try Bo3DraftEngine.choose(hero: "角色1", role: "测试", in: &series)) { error in
            XCTAssertEqual(
                error as? Bo3EngineError,
                .heroLocked(.currentGame(series.games[0].actions[0]))
            )
        }

        try fillActiveGame(&series, heroes: (2...12).map { "角色\($0)" })
        XCTAssertEqual(series.games[0].actions.count, 12)
        XCTAssertNil(Bo3DraftEngine.currentStep(in: series))
        XCTAssertThrowsError(try Bo3DraftEngine.choose(hero: "角色13", role: "测试", in: &series)) { error in
            XCTAssertEqual(error as? Bo3EngineError, .draftIncomplete)
        }
    }

    func testWinnerRequiresACompleteDraftAndCanBeReopened() throws {
        var series = try startedSeries(pool: makePool(20))
        try fillActiveGame(&series, heroes: (1...11).map { "角色\($0)" })

        XCTAssertThrowsError(try Bo3DraftEngine.setWinner(.a, in: &series)) { error in
            XCTAssertEqual(error as? Bo3EngineError, .winnerNotAllowed)
        }

        try fillActiveGame(&series, heroes: ["角色12"])
        try Bo3DraftEngine.setWinner(.a, in: &series)
        XCTAssertEqual(series.games[0].winner, .a)
        XCTAssertEqual(series.wins.a, 1)

        XCTAssertTrue(Bo3DraftEngine.reopenWinner(in: &series))
        XCTAssertNil(series.games[0].winner)
        XCTAssertEqual(series.wins.a, 0)
        XCTAssertFalse(Bo3DraftEngine.reopenWinner(in: &series))
    }

    func testSeriesWinsAndChampionForTwoZeroAndTwoOne() {
        var sweep = Bo3Series()
        sweep.games[0].winner = .a
        sweep.games[1].winner = .a
        XCTAssertEqual(sweep.wins.a, 2)
        XCTAssertTrue(sweep.isSeriesOver)
        XCTAssertEqual(sweep.champion, .a)

        var close = Bo3Series()
        close.games[0].winner = .a
        close.games[1].winner = .b
        close.games[2].winner = .a
        XCTAssertEqual(close.wins.a, 2)
        XCTAssertEqual(close.wins.b, 1)
        XCTAssertEqual(close.champion, .a)
    }

    func testUndoCancelsWinnerFirstThenTheLastAction() throws {
        var series = try startedSeries(pool: makePool(30))
        XCTAssertFalse(Bo3DraftEngine.undo(in: &series))

        try fillActiveGame(&series, heroes: (1...12).map { "角色\($0)" })
        try Bo3DraftEngine.setWinner(.a, in: &series)
        XCTAssertTrue(Bo3DraftEngine.undo(in: &series))
        XCTAssertNil(series.games[0].winner)
        XCTAssertEqual(series.games[0].actions.count, 12)

        XCTAssertTrue(Bo3DraftEngine.undo(in: &series))
        XCTAssertEqual(series.games[0].actions.count, 11)
        XCTAssertEqual(series.games[0].actions.last?.hero, "角色11")
    }

    func testUndoOnlyAffectsTheActiveGame() throws {
        var series = try startedSeries(pool: makePool(30))
        try completeActiveGame(&series, startingAt: 1, winner: .a)
        try Bo3DraftEngine.startGame(in: &series, pool: makePool(30))
        let priorActions = series.games[0].actions

        try fillActiveGame(&series, heroes: (13...24).map { "角色\($0)" })
        XCTAssertTrue(Bo3DraftEngine.undo(in: &series))
        XCTAssertEqual(series.games[0].actions, priorActions)
        XCTAssertEqual(series.games[1].actions.count, 11)
    }

    func testSeatGenerationAndValidation() {
        for _ in 0..<100 {
            let seats = Bo3DraftEngine.generateSeats()
            XCTAssertEqual(seats.a.count, 4)
            XCTAssertEqual(seats.b.count, 4)
            XCTAssertEqual(Set(seats.a + seats.b), Set(1...8))
            XCTAssertTrue(Bo3DraftEngine.isValidSeats(seats))
        }

        XCTAssertFalse(Bo3DraftEngine.isValidSeats(nil))
        XCTAssertFalse(Bo3DraftEngine.isValidSeats(Bo3Seats(a: [1, 1, 2, 3], b: [4, 5, 6, 7])))
        XCTAssertFalse(Bo3DraftEngine.isValidSeats(Bo3Seats(a: [1, 2, 3], b: [4, 5, 6, 7])))
        XCTAssertFalse(Bo3DraftEngine.isValidSeats(Bo3Seats(a: [1, 2, 3, 9], b: [4, 5, 6, 7])))
    }

    func testStartGameBlocksSmallPoolsAndAllowsTwelve() throws {
        var small = Bo3Series()
        XCTAssertThrowsError(try Bo3DraftEngine.startGame(in: &small, pool: makePool(11))) { error in
            XCTAssertEqual(
                error as? Bo3EngineError,
                .poolTooSmall(minimum: 12, actual: 11)
            )
        }

        var enough = Bo3Series()
        try Bo3DraftEngine.startGame(in: &enough, pool: makePool(12))
        XCTAssertEqual(enough.currentGame, 1)
        XCTAssertTrue(enough.games[0].started)
        XCTAssertTrue(Bo3DraftEngine.isValidSeats(enough.seats))
    }

    func testNextGameBlocksWhenRemainingPicksAreShort() throws {
        let pool = makePool(23)
        var series = try startedSeries(pool: pool)
        try fillActiveGame(&series, heroes: (1...12).map { "角色\($0)" })
        try Bo3DraftEngine.setWinner(.a, in: &series)

        try Bo3DraftEngine.startGame(in: &series, pool: pool)
        XCTAssertEqual(series.currentGame, 2)
        try fillActiveGame(
            &series,
            heroes: ["角色1", "角色2", "角色7", "角色8", "角色13", "角色14", "角色15", "角色16", "角色17", "角色18", "角色19", "角色20"]
        )
        try Bo3DraftEngine.setWinner(.b, in: &series)

        XCTAssertThrowsError(try Bo3DraftEngine.startGame(in: &series, pool: pool)) { error in
            XCTAssertEqual(
                error as? Bo3EngineError,
                .insufficientRemaining(required: 8, remaining: 7)
            )
        }
    }

    func testNextGameStartsGameThreeWithNoBanAndCompletesEightPicks() throws {
        let pool = makePool(40)
        var series = try startedSeries(pool: pool)
        try completeActiveGame(&series, startingAt: 1, winner: .a)
        try Bo3DraftEngine.startGame(in: &series, pool: pool)
        try completeActiveGame(&series, startingAt: 13, winner: .b)
        try Bo3DraftEngine.startGame(in: &series, pool: pool)

        XCTAssertEqual(series.currentGame, 3)
        XCTAssertTrue(series.games[2].noBan)
        XCTAssertEqual(Bo3DraftEngine.activeSequence(in: series).count, 8)

        try fillActiveGame(&series, heroes: (25...32).map { "角色\($0)" })
        XCTAssertEqual(series.games[2].actions.count, 8)
        XCTAssertNil(Bo3DraftEngine.currentStep(in: series))
    }

    func testCanStartNextGameReflectsWinnerAndRemainingPicks() throws {
        let pool = makePool(30)
        var series = try startedSeries(pool: pool)
        try fillActiveGame(&series, heroes: (1...12).map { "角色\($0)" })

        XCTAssertFalse(Bo3DraftEngine.canStartNextGame(in: series, pool: pool))
        try Bo3DraftEngine.setWinner(.a, in: &series)
        XCTAssertTrue(Bo3DraftEngine.canStartNextGame(in: series, pool: pool))
        XCTAssertEqual(Bo3DraftEngine.remainingPicksAvailable(in: series, pool: pool), 22)
    }

    func testRemainingPicksIgnorePickedHeroesRemovedFromThePool() throws {
        let originalPool = makePool(24)
        var series = try startedSeries(pool: originalPool)
        try completeActiveGame(&series, startingAt: 1, winner: .a)
        try Bo3DraftEngine.startGame(in: &series, pool: originalPool)
        try completeActiveGame(&series, startingAt: 13, winner: .b)
        XCTAssertEqual(series.currentGame, 2)

        // 14 heroes: eight that were only banned in games 1-2 and six that were
        // picked and are therefore globally locked. The six locked heroes are
        // no longer part of the edited pool, so they must not be subtracted
        // from its size a second time.
        let editedPool = Bo3Pool(
            text: "测试：角色1、角色2、角色3、角色4、角色5、角色6、角色7、角色8、角色9、角色10、角色13、角色14、角色19、角色20"
        )
        XCTAssertEqual(editedPool.total, 14)
        XCTAssertEqual(
            Bo3DraftEngine.remainingPicksAvailable(in: series, pool: editedPool),
            8
        )
        XCTAssertTrue(Bo3DraftEngine.canStartNextGame(in: series, pool: editedPool))

        try Bo3DraftEngine.startGame(in: &series, pool: editedPool)
        XCTAssertEqual(series.currentGame, 3)
        XCTAssertTrue(series.games[2].noBan)
    }

    func testResetClearsGamesAndSeatsButKeepsSettings() throws {
        var series = try startedSeries(pool: makePool(30))
        try fillActiveGame(&series, heroes: ["角色1"])
        series.teamNames = Bo3TeamNames(a: "红队", b: "紫队")
        series.noBanGame3 = false

        Bo3DraftEngine.reset(&series)

        XCTAssertEqual(series.currentGame, 0)
        XCTAssertNil(series.seats)
        XCTAssertTrue(series.games.allSatisfy { !$0.started && $0.actions.isEmpty && $0.winner == nil })
        XCTAssertEqual(series.teamNames.a, "红队")
        XCTAssertFalse(series.noBanGame3)
    }

    func testLockMessagesExplainCurrentAndGlobalLocks() {
        var series = Bo3Series(teamNames: Bo3TeamNames(a: "红队", b: "紫队"))
        series.currentGame = 2
        let priorPick = Bo3Action(team: .a, type: .pick, hero: "温迪", role: "射手")
        let currentBan = Bo3Action(team: .b, type: .ban, hero: "甘雨", role: "射手")
        series.games[0] = Bo3Game(started: true, actions: [priorPick])
        series.games[1] = Bo3Game(started: true, actions: [currentBan])

        let globalMessage = Bo3DraftEngine.lockMessage(
            for: .globalPick(game: 1, action: priorPick),
            in: series
        )
        XCTAssertTrue(globalMessage.contains("第 1 局"))
        XCTAssertTrue(globalMessage.contains("红队"))
        XCTAssertTrue(globalMessage.contains("全局 BP"))

        let currentMessage = Bo3DraftEngine.lockMessage(
            for: .currentGame(currentBan),
            in: series
        )
        XCTAssertTrue(currentMessage.contains("紫队"))
        XCTAssertTrue(currentMessage.contains("禁用"))
        XCTAssertTrue(currentMessage.contains("同一局"))
        XCTAssertEqual(Bo3DraftEngine.lockMessage(for: .available, in: series), "")
    }

    func testSanitizationRejectsVersionMismatchAndOutOfRangeGame() {
        var wrongVersion = Bo3Series()
        wrongVersion.version = 2
        XCTAssertEqual(Bo3DraftEngine.sanitized(wrongVersion), Bo3Series())

        var outOfRange = Bo3Series(
            teamNames: Bo3TeamNames(a: "甲", b: "乙"),
            noBanGame3: false,
            currentGame: 4
        )
        let repaired = Bo3DraftEngine.sanitized(outOfRange)
        XCTAssertEqual(repaired.currentGame, 0)
        XCTAssertEqual(repaired.teamNames.a, "甲")
        XCTAssertFalse(repaired.noBanGame3)
        XCTAssertTrue(repaired.games.allSatisfy { !$0.started && $0.actions.isEmpty })
        outOfRange.version = 1
    }

    func testSanitizationKeepsOnlyTheValidActionPrefix() {
        var series = Bo3Series(currentGame: 1)
        series.seats = Bo3Seats(a: [1, 2, 3, 4], b: [5, 6, 7, 8])
        series.games[0] = Bo3Game(
            started: true,
            actions: [
                Bo3Action(team: .a, type: .ban, hero: "甲", role: ""),
                Bo3Action(team: .b, type: .ban, hero: "甲", role: ""),
                Bo3Action(team: .a, type: .pick, hero: "乙", role: ""),
            ]
        )

        let repaired = Bo3DraftEngine.sanitized(series)
        XCTAssertEqual(repaired.games[0].actions.map(\.hero), ["甲"])
        XCTAssertNil(repaired.games[0].winner)
    }

    func testSanitizationStopsOnATeamTypeMismatch() {
        var series = Bo3Series(currentGame: 1)
        series.seats = Bo3Seats(a: [1, 2, 3, 4], b: [5, 6, 7, 8])
        series.games[0] = Bo3Game(
            started: true,
            actions: [
                Bo3Action(team: .a, type: .ban, hero: "甲", role: ""),
                Bo3Action(team: .a, type: .ban, hero: "乙", role: ""),
            ]
        )

        let repaired = Bo3DraftEngine.sanitized(series)
        XCTAssertEqual(repaired.games[0].actions.map(\.hero), ["甲"])
    }

    func testSanitizationUsesTheGame2MirroredOrder() {
        var series = Bo3Series(currentGame: 2)
        series.seats = Bo3Seats(a: [1, 2, 3, 4], b: [5, 6, 7, 8])
        series.games[1] = Bo3Game(
            started: true,
            actions: [
                Bo3Action(team: .b, type: .ban, hero: "甲", role: ""),
                Bo3Action(team: .a, type: .ban, hero: "乙", role: ""),
                Bo3Action(team: .b, type: .pick, hero: "丙", role: ""),
            ]
        )

        let repaired = Bo3DraftEngine.sanitized(series)
        XCTAssertEqual(repaired.games[1].actions.map(\.team), [.b, .a, .b])
        XCTAssertEqual(repaired.games[1].actions.count, 3)
    }

    func testSanitizationDropsAnIncompleteWinnerAndResetsFutureGames() {
        var series = Bo3Series(currentGame: 1)
        series.seats = Bo3Seats(a: [1, 2, 3, 4], b: [5, 6, 7, 8])
        series.games[0] = Bo3Game(
            started: true,
            actions: [Bo3Action(team: .a, type: .ban, hero: "甲", role: "")],
            winner: .a
        )
        series.games[1] = Bo3Game(
            started: true,
            actions: [Bo3Action(team: .b, type: .pick, hero: "乙", role: "")]
        )

        let repaired = Bo3DraftEngine.sanitized(series)
        XCTAssertNil(repaired.games[0].winner)
        XCTAssertFalse(repaired.games[1].started)
        XCTAssertTrue(repaired.games[1].actions.isEmpty)
    }

    func testSanitizationRepairsSeatsAndNormalizesNames() {
        var series = Bo3Series(currentGame: 1)
        series.teamNames = Bo3TeamNames(a: "   ", b: String(repeating: "长", count: 20))
        series.seats = Bo3Seats(a: [1, 1, 2, 3], b: [4, 5, 6, 7])

        let repaired = Bo3DraftEngine.sanitized(series)
        XCTAssertEqual(repaired.teamNames.a, "A 队")
        XCTAssertEqual(repaired.teamNames.b.count, 16)
        XCTAssertTrue(Bo3DraftEngine.isValidSeats(repaired.seats))
    }

    func testSanitizationHandlesMissingHeroAndGameThreeNoBan() throws {
        let missingHeroJSON = #"{"team":"a","type":"ban"}"#
        let missingHero = try JSONDecoder().decode(
            Bo3Action.self,
            from: Data(missingHeroJSON.utf8)
        )
        XCTAssertEqual(missingHero.hero, "")

        var series = Bo3Series(noBanGame3: true, currentGame: 3)
        series.seats = Bo3Seats(a: [1, 2, 3, 4], b: [5, 6, 7, 8])
        series.games[0] = Bo3Game(started: true, actions: [missingHero])
        series.games[2] = Bo3Game(
            started: true,
            actions: Bo3DraftEngine.game3NoBanSequence.enumerated().map { offset, step in
                Bo3Action(team: step.team, type: step.type, hero: "角色\(offset)", role: "测试")
            },
            noBan: true
        )

        let repaired = Bo3DraftEngine.sanitized(series)
        XCTAssertTrue(repaired.games[0].actions.isEmpty)
        XCTAssertEqual(repaired.games[2].actions.count, 8)
        XCTAssertTrue(repaired.games[2].noBan)
    }
}
