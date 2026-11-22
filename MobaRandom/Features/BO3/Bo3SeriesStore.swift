import Foundation
import Observation

/// Owns the mutable BO3 series and its local persistence. Every mutation goes
/// through the pure engine and then writes the sanitized state in one place.
@MainActor
@Observable
final class Bo3SeriesStore {
    static let storageKey = "moba_bo3_series_v1"

    private(set) var series: Bo3Series
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-moba_reset_bo3_series") {
            defaults.removeObject(forKey: Self.storageKey)
        }
        #endif
        series = Self.load(from: defaults)
    }

    var canUndo: Bool {
        Bo3DraftEngine.canUndo(in: series)
    }

    var hasProgress: Bool {
        series.hasProgress
    }

    func startGame(pool: Bo3Pool) throws {
        var updated = series
        try Bo3DraftEngine.startGame(in: &updated, pool: pool)
        series = updated
        save()
    }

    func choose(hero: String, role: String) throws {
        var updated = series
        try Bo3DraftEngine.choose(hero: hero, role: role, in: &updated)
        series = updated
        save()
    }

    func setWinner(_ team: Bo3Team) throws {
        var updated = series
        try Bo3DraftEngine.setWinner(team, in: &updated)
        series = updated
        save()
    }

    @discardableResult
    func reopenWinner() -> Bool {
        var updated = series
        guard Bo3DraftEngine.reopenWinner(in: &updated) else { return false }
        series = updated
        save()
        return true
    }

    @discardableResult
    func undo() -> Bool {
        var updated = series
        guard Bo3DraftEngine.undo(in: &updated) else { return false }
        series = updated
        save()
        return true
    }

    func reset() {
        var updated = series
        Bo3DraftEngine.reset(&updated)
        series = updated
        save()
    }

    func updateTeamNames(_ names: Bo3TeamNames) {
        var updated = series
        updated.teamNames = Bo3DraftEngine.normalizedTeamNames(names)
        series = updated
        save()
    }

    func updateNoBanGame3(_ enabled: Bool) {
        var updated = series
        updated.noBanGame3 = enabled
        series = updated
        save()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(series) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> Bo3Series {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Bo3Series.self, from: data) else {
            return Bo3Series()
        }
        return Bo3DraftEngine.sanitized(decoded)
    }
}
