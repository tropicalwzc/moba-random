import Foundation

/// Performs the one-time bundled-preset migration before any screen reads the
/// shared role pool. Keeping this outside the SwiftUI view hierarchy means a
/// restored BO3 tab cannot observe an empty pool on first launch.
enum AppBootstrap {
    static let poolKey = "moba_role_pool"
    static let weightsKey = "moba_role_weights_v1"

    static func applyBuiltInWeightPresetIfNeeded(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main
    ) {
        let storedPool = defaults.string(forKey: poolKey) ?? ""
        let normalizedStoredPool = normalizedPoolText(storedPool)
        let hasStoredPool = !normalizedStoredPool.isEmpty
        let isBuiltInPool = !hasStoredPool || knownDefaultPoolTexts.contains {
            normalizedPoolText($0) == normalizedStoredPool
        }

        if !hasStoredPool {
            defaults.set(GroupingEngine.defaultPoolText, forKey: poolKey)
        }

        guard BuiltInWeightPresetMigration.isPending(in: defaults) else { return }

        guard isBuiltInPool else {
            // A pre-marker upgrade may already contain a customized pool and
            // weights. Keep both and record the one-time migration as handled.
            BuiltInWeightPresetMigration.markApplied(in: defaults)
            return
        }

        let lanes = GroupingEngine.parseRolePool(GroupingEngine.defaultPoolText).map(\.name)
        guard let imported = try? BuiltInWeightPresetMigration.load(from: bundle, currentLanes: lanes),
              let data = try? JSONEncoder().encode(imported.configuration),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }

        defaults.set(encoded, forKey: weightsKey)
        defaults.set(imported.poolText, forKey: poolKey)
        BuiltInWeightPresetMigration.markApplied(in: defaults)
    }

    /// Defaults that may have been stored by older builds or imported from the
    /// reference page. Only these built-in pools are replaced by the 34-name
    /// preset; an arbitrary custom pool is preserved on upgrade.
    private static let knownDefaultPoolTexts: [String] = [
        GroupingEngine.defaultPoolText,
        """
        射手：温迪、甘雨、宵宫、提纳里、公子、夜兰
        打野：绫华、胡桃、雷神、刻晴、牢大
        中路：希格雯、钟离、神子、龙王、少女、纳西妲、可莉
        战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、迪卢克、洛恩、琴、杜林
        """,
        """
        射手：温迪、甘雨、宵宫、提纳里、公子
        打野：绫华、胡桃、雷神、刻晴、牢大
        中路：希格雯、钟离、八重、龙王、少女、夜兰、纳西妲
        战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈
        """,
        """
        射手：温迪、甘雨、宵宫、提纳里、公子、夜兰、赛索斯
        打野：绫华、胡桃、雷神、刻晴、牢大
        中路：希格雯、钟离、八重、龙王、少女、纳西妲、可莉
        战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、琴、洛恩、迪卢克、杜林、法尔加、克洛林德、赛诺
        """,
        """
        射手：温迪、甘雨、宵宫、提纳里、公子、夜兰、赛索斯
        打野：绫华、胡桃、雷神、刻晴、牢大、魈
        中路：希格雯、钟离、八重、龙王、少女、纳西妲、可莉
        战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、琴、洛恩、迪卢克、杜林、法尔加、克洛林德、赛诺
        """,
    ]

    private static func normalizedPoolText(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
