import Foundation

enum Bo3Team: String, Codable, CaseIterable, Sendable {
    case a
    case b

    var sideLabel: String {
        self == .a ? "红方" : "紫方"
    }

    var shortLabel: String {
        self == .a ? "A" : "B"
    }
}

enum Bo3ActionType: String, Codable, Sendable {
    case ban
    case pick

    var label: String {
        self == .ban ? "禁用" : "选用"
    }

    var shortLabel: String {
        self == .ban ? "禁" : "选"
    }
}

struct Bo3Step: Equatable, Sendable {
    let team: Bo3Team
    let type: Bo3ActionType
}

struct Bo3Action: Codable, Equatable, Sendable {
    let team: Bo3Team
    let type: Bo3ActionType
    let hero: String
    let role: String

    init(team: Bo3Team, type: Bo3ActionType, hero: String, role: String) {
        self.team = team
        self.type = type
        self.hero = hero
        self.role = role
    }

    private enum CodingKeys: String, CodingKey {
        case team, type, hero, role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        team = try container.decode(Bo3Team.self, forKey: .team)
        type = try container.decode(Bo3ActionType.self, forKey: .type)
        hero = try container.decodeIfPresent(String.self, forKey: .hero) ?? ""
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
    }
}

struct Bo3Game: Codable, Equatable, Sendable {
    var started: Bool
    var actions: [Bo3Action]
    var winner: Bo3Team?
    var noBan: Bool

    init(
        started: Bool = false,
        actions: [Bo3Action] = [],
        winner: Bo3Team? = nil,
        noBan: Bool = false
    ) {
        self.started = started
        self.actions = actions
        self.winner = winner
        self.noBan = noBan
    }

    private enum CodingKeys: String, CodingKey {
        case started, actions, winner, noBan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        started = try container.decodeIfPresent(Bool.self, forKey: .started) ?? false
        actions = try container.decodeIfPresent([Bo3Action].self, forKey: .actions) ?? []
        winner = try container.decodeIfPresent(Bo3Team.self, forKey: .winner)
        noBan = try container.decodeIfPresent(Bool.self, forKey: .noBan) ?? false
    }
}

struct Bo3Seats: Codable, Equatable, Sendable {
    var a: [Int]
    var b: [Int]
}

struct Bo3TeamNames: Codable, Equatable, Sendable {
    var a: String
    var b: String

    init(a: String = "A 队", b: String = "B 队") {
        self.a = a
        self.b = b
    }

    func name(for team: Bo3Team) -> String {
        team == .a ? a : b
    }
}

struct Bo3Series: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let gameCount = 3

    var version: Int
    var teamNames: Bo3TeamNames
    var noBanGame3: Bool
    var seats: Bo3Seats?
    var currentGame: Int
    var games: [Bo3Game]

    init(
        version: Int = currentVersion,
        teamNames: Bo3TeamNames = Bo3TeamNames(),
        noBanGame3: Bool = true,
        seats: Bo3Seats? = nil,
        currentGame: Int = 0,
        games: [Bo3Game] = Array(repeating: Bo3Game(), count: Bo3Series.gameCount)
    ) {
        self.version = version
        self.teamNames = teamNames
        self.noBanGame3 = noBanGame3
        self.seats = seats
        self.currentGame = currentGame
        self.games = games
    }

    var activeGame: Bo3Game? {
        guard currentGame >= 1, currentGame <= Self.gameCount else { return nil }
        return games[currentGame - 1]
    }

    var wins: (a: Int, b: Int) {
        games.reduce(into: (a: 0, b: 0)) { result, game in
            switch game.winner {
            case .a: result.a += 1
            case .b: result.b += 1
            case nil: break
            }
        }
    }

    var isSeriesOver: Bool {
        wins.a >= 2 || wins.b >= 2
    }

    var champion: Bo3Team? {
        if wins.a >= 2 { return .a }
        if wins.b >= 2 { return .b }
        return nil
    }

    var hasProgress: Bool {
        currentGame > 0 || games.contains { $0.started || !$0.actions.isEmpty || $0.winner != nil }
    }
}

enum Bo3Availability: Equatable, Sendable {
    case available
    case currentGame(Bo3Action)
    case globalPick(game: Int, action: Bo3Action)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

struct Bo3PoolHealth: Equatable, Sendable {
    let total: Int
    let duplicates: [String]

    var canStartGame: Bool { total >= Bo3DraftEngine.minimumPoolForGame }
    var canCompleteNoBanGame3: Bool { total >= Bo3DraftEngine.minimumPoolForNoBanGame3 }
    var canCompleteFullGame3: Bool { total >= Bo3DraftEngine.minimumPoolForFullGame3 }

    var summary: String {
        let base: String
        if !canStartGame {
            base = "角色池 \(total) 人，至少需要 \(Bo3DraftEngine.minimumPoolForGame) 人才能开始一局。"
        } else if !canCompleteNoBanGame3 {
            base = "角色池 \(total) 人，可开始对局；完成三局建议至少 \(Bo3DraftEngine.minimumPoolForNoBanGame3) 人。"
        } else if !canCompleteFullGame3 {
            base = "角色池 \(total) 人，可完成无 BAN 的第 3 局；完整第 3 局建议至少 \(Bo3DraftEngine.minimumPoolForFullGame3) 人。"
        } else {
            base = "角色池 \(total) 人，两种赛制都足够。"
        }
        guard !duplicates.isEmpty else { return base }
        let shown = duplicates.prefix(5).joined(separator: "、")
        let suffix = duplicates.count > 5 ? " 等" : ""
        return base + " 已忽略重复：\(shown)\(suffix)。"
    }
}
