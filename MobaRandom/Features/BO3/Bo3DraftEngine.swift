import Foundation

enum Bo3EngineError: LocalizedError, Equatable {
    case poolTooSmall(minimum: Int, actual: Int)
    case insufficientRemaining(required: Int, remaining: Int)
    case noActiveGame
    case draftIncomplete
    case winnerRequired
    case seriesOver
    case heroLocked(Bo3Availability)
    case emptyHero
    case winnerNotAllowed
    case nothingToUndo
    case cannotStartNextGame

    var errorDescription: String? {
        switch self {
        case let .poolTooSmall(minimum, actual):
            "角色池不足 \(minimum) 名角色，当前 \(actual) 名。请先补充角色池。"
        case let .insufficientRemaining(required, remaining):
            "剩余可选角色仅 \(remaining) 名，不足以下一局的 \(required) 手征召。请扩充角色池，或重置后重新开始。"
        case .noActiveGame:
            "请先开始一局比赛。"
        case .draftIncomplete:
            "请先完成本局征召。"
        case .winnerRequired:
            "请先判定本局胜者。"
        case .seriesOver:
            "系列赛已结束，请使用全局重置开启新的系列赛。"
        case .heroLocked:
            "该角色当前不可选。"
        case .emptyHero:
            "角色名称不能为空。"
        case .winnerNotAllowed:
            "征召完成后才能判定本局胜者。"
        case .nothingToUndo:
            "本局还没有可撤销的操作。"
        case .cannotStartNextGame:
            "请先完成本局征召并判定胜者。"
        }
    }
}

/// Pure rules for the BO3 global-BP board. No SwiftUI or persistence imports.
///
/// Invariants:
/// - Game 1 uses `stepSequence`; game 2 uses `game2StepSequence`, which
///   mirrors every team assignment (bans and picks); game 3 uses
///   `game3NoBanSequence` only when its started `noBan` flag (or, before it
///   starts, the series setting) is true.
/// - A hero is unavailable if it appears in any action of the active game, or
///   if it was picked in any earlier game. Earlier bans are deliberately free.
/// - A winner is only meaningful once every step of the active sequence has an
///   action; sanitization drops incomplete winners.
enum Bo3DraftEngine {
    static let minimumPoolForGame = 12
    static let minimumPoolForNoBanGame3 = 24
    static let minimumPoolForFullGame3 = 28

    /// 12-step draft used by games 1 and 2.
    static let stepSequence: [Bo3Step] = [
        Bo3Step(team: .a, type: .ban),
        Bo3Step(team: .b, type: .ban),
        Bo3Step(team: .a, type: .pick),
        Bo3Step(team: .b, type: .pick),
        Bo3Step(team: .b, type: .pick),
        Bo3Step(team: .a, type: .pick),
        Bo3Step(team: .a, type: .ban),
        Bo3Step(team: .b, type: .ban),
        Bo3Step(team: .b, type: .pick),
        Bo3Step(team: .a, type: .pick),
        Bo3Step(team: .a, type: .pick),
        Bo3Step(team: .b, type: .pick),
    ]

    /// Game 2 mirrors every A/B assignment, so the same team does not get the
    /// first ban and first pick in every game. Step types and the overall
    /// draft shape are unchanged.
    static let game2StepSequence: [Bo3Step] = stepSequence.map { step in
        Bo3Step(team: step.team == .a ? .b : .a, type: step.type)
    }

    /// 8-pick draft used by a no-ban game 3. Kept explicit for readability and
    /// checked against `stepSequence` by tests.
    static let game3NoBanSequence: [Bo3Step] = [
        Bo3Step(team: .a, type: .pick),
        Bo3Step(team: .b, type: .pick),
        Bo3Step(team: .b, type: .pick),
        Bo3Step(team: .a, type: .pick),
        Bo3Step(team: .b, type: .pick),
        Bo3Step(team: .a, type: .pick),
        Bo3Step(team: .a, type: .pick),
        Bo3Step(team: .b, type: .pick),
    ]

    static func usesNoBan(for gameNo: Int, in series: Bo3Series) -> Bool {
        guard gameNo == 3 else { return false }
        let game = series.games[2]
        return game.started ? game.noBan : series.noBanGame3
    }

    static func sequence(for gameNo: Int, in series: Bo3Series) -> [Bo3Step] {
        if gameNo == 2 {
            return game2StepSequence
        }
        if gameNo == 3 && usesNoBan(for: gameNo, in: series) {
            return game3NoBanSequence
        }
        return stepSequence
    }

    static func activeSequence(in series: Bo3Series) -> [Bo3Step] {
        guard series.currentGame > 0 else { return stepSequence }
        return sequence(for: series.currentGame, in: series)
    }

    static func currentStep(in series: Bo3Series) -> (step: Bo3Step, index: Int)? {
        guard let game = series.activeGame, game.started else { return nil }
        let sequence = activeSequence(in: series)
        guard game.actions.count < sequence.count else { return nil }
        return (sequence[game.actions.count], game.actions.count)
    }

    /// Current-game actions lock first, then prior-game picks. Prior bans never
    /// lock. The current-game case is returned preferentially so the UI can
    /// explain the most local reason.
    static func availability(of hero: String, in series: Bo3Series) -> Bo3Availability {
        if let game = series.activeGame,
           let action = game.actions.first(where: { $0.hero == hero }) {
            return .currentGame(action)
        }

        let priorGameCount = max(0, series.currentGame - 1)
        for index in 0..<min(priorGameCount, series.games.count) {
            let game = series.games[index]
            guard game.started else { continue }
            if let action = game.actions.first(where: { $0.type == .pick && $0.hero == hero }) {
                return .globalPick(game: index + 1, action: action)
            }
        }
        return .available
    }

    static func availabilityMap(
        for heroes: [String],
        in series: Bo3Series
    ) -> [String: Bo3Availability] {
        Dictionary(uniqueKeysWithValues: heroes.map { ($0, availability(of: $0, in: series)) })
    }

    /// Picks through the requested game number. Use the current game when
    /// deciding whether the next game has enough characters left.
    static func pickedHeroes(
        in series: Bo3Series,
        throughGameNumber: Int? = nil
    ) -> Set<String> {
        let requested = throughGameNumber ?? series.currentGame
        let upper = min(max(requested, 0), series.games.count)
        var heroes = Set<String>()
        for index in 0..<upper {
            for action in series.games[index].actions where action.type == .pick {
                heroes.insert(action.hero)
            }
        }
        return heroes
    }

    static func currentGameHeroes(in series: Bo3Series) -> Set<String> {
        Set(series.activeGame?.actions.map(\.hero) ?? [])
    }

    static func remainingPicksAvailable(in series: Bo3Series, pool: Bo3Pool) -> Int {
        // Prior picks that are no longer in the pool must not reduce the count:
        // they are not part of `pool` and cannot be selected again anyway.
        let locked = pickedHeroes(in: series, throughGameNumber: series.currentGame)
        return pool.allHeroes.filter { !locked.contains($0) }.count
    }

    static func nextGameRequirement(in series: Bo3Series) -> Int {
        let nextGame = min(3, max(1, series.currentGame + 1))
        return sequence(for: nextGame, in: series).count
    }

    static func canStartNextGame(in series: Bo3Series, pool: Bo3Pool) -> Bool {
        if series.currentGame == 0 {
            return pool.total >= minimumPoolForGame
        }
        guard series.currentGame < 3,
              let game = series.activeGame,
              game.started,
              game.actions.count >= activeSequence(in: series).count,
              game.winner != nil,
              !series.isSeriesOver else {
            return false
        }
        return remainingPicksAvailable(in: series, pool: pool) >= nextGameRequirement(in: series)
    }

    static func poolHealth(for pool: Bo3Pool) -> Bo3PoolHealth {
        Bo3PoolHealth(total: pool.total, duplicates: pool.duplicates)
    }

    static func canUndo(in series: Bo3Series) -> Bool {
        guard let game = series.activeGame else { return false }
        return game.winner != nil || !game.actions.isEmpty
    }

    static func lockMessage(for availability: Bo3Availability, in series: Bo3Series) -> String {
        switch availability {
        case .available:
            return ""
        case let .currentGame(action):
            return "该角色本局已被 \(series.teamNames.name(for: action.team)) \(action.type.label)，同一局内不可重复选择。"
        case let .globalPick(game, action):
            return "该角色已在第 \(game) 局被 \(series.teamNames.name(for: action.team)) 选用，全局 BP 锁定。"
        }
    }

    // MARK: - Mutations

    static func startGame(in series: inout Bo3Series, pool: Bo3Pool) throws {
        if series.currentGame == 0 {
            guard pool.total >= minimumPoolForGame else {
                throw Bo3EngineError.poolTooSmall(minimum: minimumPoolForGame, actual: pool.total)
            }
            series.games = Array(repeating: Bo3Game(), count: Bo3Series.gameCount)
            series.seats = generateSeats()
            series.currentGame = 1
            series.games[0].started = true
            series.games[0].noBan = false
            return
        }

        guard series.currentGame >= 1, series.currentGame <= 3, let game = series.activeGame else {
            throw Bo3EngineError.cannotStartNextGame
        }
        let currentSequence = activeSequence(in: series)
        guard game.actions.count >= currentSequence.count else {
            throw Bo3EngineError.draftIncomplete
        }
        guard game.winner != nil else {
            throw Bo3EngineError.winnerRequired
        }
        guard !series.isSeriesOver else {
            throw Bo3EngineError.seriesOver
        }
        guard series.currentGame < 3 else {
            throw Bo3EngineError.seriesOver
        }

        let nextGame = series.currentGame + 1
        let nextSequence = sequence(for: nextGame, in: series)
        let remaining = remainingPicksAvailable(in: series, pool: pool)
        guard remaining >= nextSequence.count else {
            throw Bo3EngineError.insufficientRemaining(
                required: nextSequence.count,
                remaining: remaining
            )
        }

        series.currentGame = nextGame
        series.games[nextGame - 1] = Bo3Game(
            started: true,
            noBan: nextGame == 3 && series.noBanGame3
        )
    }

    static func choose(hero: String, role: String, in series: inout Bo3Series) throws {
        guard let game = series.activeGame, game.started else {
            throw Bo3EngineError.noActiveGame
        }
        let currentSequence = activeSequence(in: series)
        guard game.actions.count < currentSequence.count else {
            throw Bo3EngineError.draftIncomplete
        }

        let trimmedHero = hero.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHero.isEmpty else {
            throw Bo3EngineError.emptyHero
        }

        let state = availability(of: trimmedHero, in: series)
        guard state.isAvailable else {
            throw Bo3EngineError.heroLocked(state)
        }

        let step = currentSequence[game.actions.count]
        series.games[series.currentGame - 1].actions.append(
            Bo3Action(
                team: step.team,
                type: step.type,
                hero: trimmedHero,
                role: role.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    static func setWinner(_ team: Bo3Team, in series: inout Bo3Series) throws {
        guard let game = series.activeGame, game.started else {
            throw Bo3EngineError.noActiveGame
        }
        guard game.actions.count == activeSequence(in: series).count else {
            throw Bo3EngineError.winnerNotAllowed
        }
        series.games[series.currentGame - 1].winner = team
    }

    @discardableResult
    static func reopenWinner(in series: inout Bo3Series) -> Bool {
        guard let game = series.activeGame, game.started, game.winner != nil else {
            return false
        }
        series.games[series.currentGame - 1].winner = nil
        return true
    }

    @discardableResult
    static func undo(in series: inout Bo3Series) -> Bool {
        guard let game = series.activeGame else { return false }
        if game.winner != nil {
            series.games[series.currentGame - 1].winner = nil
            return true
        }
        guard !game.actions.isEmpty else { return false }
        series.games[series.currentGame - 1].actions.removeLast()
        return true
    }

    static func reset(_ series: inout Bo3Series) {
        series.currentGame = 0
        series.seats = nil
        series.games = Array(repeating: Bo3Game(), count: Bo3Series.gameCount)
    }

    // MARK: - Seats

    static func generateSeats() -> Bo3Seats {
        let numbers = (1...8).shuffled()
        return Bo3Seats(
            a: Array(numbers.prefix(4)),
            b: Array(numbers.suffix(4))
        )
    }

    static func isValidSeats(_ seats: Bo3Seats?) -> Bool {
        guard let seats, seats.a.count == 4, seats.b.count == 4 else { return false }
        let all = seats.a + seats.b
        return all.count == 8
            && Set(all).count == 8
            && all.allSatisfy { (1...8).contains($0) }
    }

    // MARK: - Sanitization

    /// Repairs a decoded series without trusting corrupt action ordering.
    /// Actions are copied only while they match the expected step and do not
    /// repeat a hero. The first mismatch ends the game's action list.
    static func sanitized(_ decoded: Bo3Series) -> Bo3Series {
        guard decoded.version == Bo3Series.currentVersion else {
            return Bo3Series()
        }

        var series = decoded
        series.teamNames = normalizedTeamNames(decoded.teamNames)

        guard (0...3).contains(decoded.currentGame) else {
            return Bo3Series(
                teamNames: series.teamNames,
                noBanGame3: decoded.noBanGame3
            )
        }

        var games: [Bo3Game] = []
        for index in 0..<Bo3Series.gameCount {
            let source = index < decoded.games.count ? decoded.games[index] : Bo3Game()
            let noBan = index == 2 ? source.noBan : false
            let sequence: [Bo3Step]
            if index == 1 {
                sequence = game2StepSequence
            } else if index == 2 && noBan {
                sequence = game3NoBanSequence
            } else {
                sequence = stepSequence
            }
            var game = Bo3Game(started: source.started, noBan: noBan)

            var seen = Set<String>()
            for (offset, action) in source.actions.prefix(sequence.count).enumerated() {
                let hero = action.hero.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !hero.isEmpty,
                      !seen.contains(hero),
                      action.team == sequence[offset].team,
                      action.type == sequence[offset].type else {
                    break
                }
                let role = action.role.trimmingCharacters(in: .whitespacesAndNewlines)
                game.actions.append(
                    Bo3Action(
                        team: sequence[offset].team,
                        type: sequence[offset].type,
                        hero: String(hero.prefix(40)),
                        role: String(role.prefix(20))
                    )
                )
                seen.insert(hero)
            }

            if game.actions.count == sequence.count, let winner = source.winner {
                game.winner = winner
            }
            game.started = source.started || !game.actions.isEmpty
            games.append(game)
        }

        series.games = games
        series.currentGame = decoded.currentGame

        if series.currentGame > 0 {
            series.games[series.currentGame - 1].started = true
            for index in series.currentGame..<Bo3Series.gameCount {
                series.games[index] = Bo3Game()
            }
            if !isValidSeats(series.seats) {
                series.seats = generateSeats()
            }
        } else {
            series.games = Array(repeating: Bo3Game(), count: Bo3Series.gameCount)
            series.seats = nil
        }

        return series
    }

    static func normalizedTeamNames(_ names: Bo3TeamNames) -> Bo3TeamNames {
        Bo3TeamNames(
            a: normalizedName(names.a, fallback: "A 队"),
            b: normalizedName(names.b, fallback: "B 队")
        )
    }

    private static func normalizedName(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(16))
    }
}
