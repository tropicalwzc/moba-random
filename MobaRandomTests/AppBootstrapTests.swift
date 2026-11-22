import XCTest
@testable import MobaRandom

final class AppBootstrapTests: XCTestCase {
    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AppBootstrapTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create an isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func decodedWeights(from defaults: UserDefaults) throws -> RoleWeightConfiguration {
        let json = try XCTUnwrap(defaults.string(forKey: AppBootstrap.weightsKey))
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(RoleWeightConfiguration.self, from: data)
    }

    func testPendingMarkerAppliesTheThirtyFourCharacterPreset() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppBootstrap.applyBuiltInWeightPresetIfNeeded(defaults: defaults, bundle: .main)

        XCTAssertEqual(defaults.string(forKey: AppBootstrap.poolKey), GroupingEngine.defaultPoolText)
        XCTAssertFalse(BuiltInWeightPresetMigration.isPending(in: defaults))
        XCTAssertEqual(try decodedWeights(from: defaults).characters.count, 34)
    }

    func testExistingMarkerPreservesTheUserPoolAndWeights() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let customPool = "射手：自定义甲、自定义乙"
        defaults.set(customPool, forKey: AppBootstrap.poolKey)
        defaults.set("{\"custom\":true}", forKey: AppBootstrap.weightsKey)
        BuiltInWeightPresetMigration.markApplied(in: defaults)

        AppBootstrap.applyBuiltInWeightPresetIfNeeded(defaults: defaults, bundle: .main)

        XCTAssertEqual(defaults.string(forKey: AppBootstrap.poolKey), customPool)
        XCTAssertEqual(defaults.string(forKey: AppBootstrap.weightsKey), "{\"custom\":true}")
    }

    func testPendingMarkerPreservesACustomPoolAndItsWeights() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let customPool = "射手：自定义甲、自定义乙"
        defaults.set(customPool, forKey: AppBootstrap.poolKey)
        defaults.set("{\"custom\":true}", forKey: AppBootstrap.weightsKey)

        AppBootstrap.applyBuiltInWeightPresetIfNeeded(defaults: defaults, bundle: .main)

        XCTAssertEqual(defaults.string(forKey: AppBootstrap.poolKey), customPool)
        XCTAssertEqual(defaults.string(forKey: AppBootstrap.weightsKey), "{\"custom\":true}")
        XCTAssertFalse(BuiltInWeightPresetMigration.isPending(in: defaults))
    }

    func testPendingMarkerUpgradesAKnownLegacyDefaultPool() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(
            """
            射手：温迪、甘雨、宵宫、提纳里、公子、夜兰
            打野：绫华、胡桃、雷神、刻晴、牢大
            中路：希格雯、钟离、神子、龙王、少女、纳西妲、可莉
            战士：菲林斯、行秋、女仆、仆人、班尼特、丝柯克、点刀、魈、迪卢克、洛恩、琴、杜林
            """,
            forKey: AppBootstrap.poolKey
        )

        AppBootstrap.applyBuiltInWeightPresetIfNeeded(defaults: defaults, bundle: .main)

        XCTAssertEqual(defaults.string(forKey: AppBootstrap.poolKey), GroupingEngine.defaultPoolText)
        XCTAssertFalse(BuiltInWeightPresetMigration.isPending(in: defaults))
        XCTAssertEqual(try decodedWeights(from: defaults).characters.count, 34)
    }

    func testFailedPresetRetriesAfterTheFallbackDefaultPoolWasStored() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppBootstrap.applyBuiltInWeightPresetIfNeeded(
            defaults: defaults,
            bundle: Bundle(for: AppBootstrapTests.self)
        )
        XCTAssertTrue(BuiltInWeightPresetMigration.isPending(in: defaults))
        XCTAssertEqual(defaults.string(forKey: AppBootstrap.poolKey), GroupingEngine.defaultPoolText)

        AppBootstrap.applyBuiltInWeightPresetIfNeeded(defaults: defaults, bundle: .main)

        XCTAssertFalse(BuiltInWeightPresetMigration.isPending(in: defaults))
        XCTAssertEqual(defaults.string(forKey: AppBootstrap.poolKey), GroupingEngine.defaultPoolText)
        XCTAssertEqual(try decodedWeights(from: defaults).characters.count, 34)
    }

    func testMissingPresetLeavesTheMarkerPendingAndKeepsAUsablePool() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppBootstrap.applyBuiltInWeightPresetIfNeeded(
            defaults: defaults,
            bundle: Bundle(for: AppBootstrapTests.self)
        )

        XCTAssertTrue(BuiltInWeightPresetMigration.isPending(in: defaults))
        XCTAssertEqual(defaults.string(forKey: AppBootstrap.poolKey), GroupingEngine.defaultPoolText)
        XCTAssertNil(defaults.string(forKey: AppBootstrap.weightsKey))
    }

    func testSecondLaunchDoesNotOverwriteLaterUserEdits() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppBootstrap.applyBuiltInWeightPresetIfNeeded(defaults: defaults, bundle: .main)
        let firstWeights = defaults.string(forKey: AppBootstrap.weightsKey)

        let editedPool = "射手：编辑后的甲、编辑后的乙"
        defaults.set(editedPool, forKey: AppBootstrap.poolKey)
        AppBootstrap.applyBuiltInWeightPresetIfNeeded(defaults: defaults, bundle: .main)

        XCTAssertEqual(defaults.string(forKey: AppBootstrap.poolKey), editedPool)
        XCTAssertEqual(defaults.string(forKey: AppBootstrap.weightsKey), firstWeights)
    }
}
