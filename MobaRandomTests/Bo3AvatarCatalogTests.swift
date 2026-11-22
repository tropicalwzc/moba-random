import XCTest
@testable import MobaRandom

final class Bo3AvatarCatalogTests: XCTestCase {
    @MainActor
    func testIndexLoadsAllReferenceAvatarsAndAliases() {
        let catalog = Bo3AvatarCatalog(bundle: .main)

        XCTAssertEqual(catalog.avatarCount, 131)
        XCTAssertGreaterThan(catalog.aliasCount, 0)
    }

    @MainActor
    func testOfficialNameAndAliasResolution() {
        let catalog = Bo3AvatarCatalog(bundle: .main)

        let venti = catalog.descriptor(for: "温迪")
        XCTAssertEqual(venti.officialName, "温迪")
        XCTAssertEqual(venti.element, "风")
        XCTAssertTrue(venti.hasImage)

        let childe = catalog.descriptor(for: "公子")
        XCTAssertEqual(childe.officialName, "达达利亚")
        XCTAssertEqual(childe.element, "水")
        XCTAssertTrue(childe.hasImage)
    }

    @MainActor
    func testEveryDefaultCharacterExceptDianDaoHasAPortrait() {
        let catalog = Bo3AvatarCatalog(bundle: .main)
        let categories = GroupingEngine.parseRolePool(GroupingEngine.defaultPoolText)

        for category in categories {
            for name in category.roles where name != "点刀" {
                XCTAssertTrue(
                    catalog.descriptor(for: name).hasImage,
                    "expected a portrait for \(name)"
                )
            }
        }

        XCTAssertFalse(catalog.descriptor(for: "点刀").hasImage)
    }

    @MainActor
    func testUnknownNameAndMissingImageFallBack() {
        let catalog = Bo3AvatarCatalog(bundle: .main)
        let unknown = catalog.descriptor(for: "完全未知的角色")

        XCTAssertNil(unknown.officialName)
        XCTAssertNil(unknown.file)
        XCTAssertFalse(unknown.hasImage)
        XCTAssertNil(catalog.image(for: unknown))
        XCTAssertNil(catalog.image(named: "点刀"))
    }

    @MainActor
    func testKnownWebPImageLoads() {
        let catalog = Bo3AvatarCatalog(bundle: .main)

        XCTAssertNotNil(catalog.image(named: "温迪"))
        XCTAssertNotNil(catalog.image(named: "公子"))
    }

    func testRoleAndElementPalette() {
        XCTAssertEqual(Bo3Palette.roleValue(for: "射手"), Bo3ColorValue(hex: 0xF2C86B))
        XCTAssertEqual(Bo3Palette.roleValue(for: "打野"), Bo3ColorValue(hex: 0x4ADE80))
        XCTAssertEqual(Bo3Palette.roleValue(for: "中路"), Bo3ColorValue(hex: 0xA78BFA))
        XCTAssertEqual(Bo3Palette.roleValue(for: "战士"), Bo3ColorValue(hex: 0xFB7185))
        XCTAssertEqual(Bo3Palette.roleValue(for: "辅助"), Bo3ColorValue(hex: 0x38BDF8))
        XCTAssertEqual(Bo3Palette.roleValue(for: "坦克"), Bo3ColorValue(hex: 0xFBBF24))

        let custom = Bo3Palette.roleValue(for: "自定义职业")
        XCTAssertEqual(custom, Bo3Palette.roleValue(for: "自定义职业"))

        XCTAssertEqual(Bo3Palette.elementValue(for: "风"), Bo3ColorValue(hex: 0x7AD7B5))
        XCTAssertEqual(Bo3Palette.elementValue(for: "火"), Bo3ColorValue(hex: 0xFF8B6B))
        XCTAssertEqual(Bo3Palette.elementValue(for: "水"), Bo3ColorValue(hex: 0x59B9FF))
        XCTAssertEqual(Bo3Palette.elementValue(for: "冰"), Bo3ColorValue(hex: 0xA9E8FF))
        XCTAssertEqual(Bo3Palette.elementValue(for: "雷"), Bo3ColorValue(hex: 0xC6A3FF))
        XCTAssertEqual(Bo3Palette.elementValue(for: "岩"), Bo3ColorValue(hex: 0xF0C96F))
        XCTAssertEqual(Bo3Palette.elementValue(for: "草"), Bo3ColorValue(hex: 0x93DC72))
        XCTAssertNil(Bo3Palette.elementValue(for: "未知"))
    }

    func testFallbackHashAndHuesAreStable() {
        XCTAssertEqual(Bo3Palette.hash("温迪"), Bo3Palette.hash("温迪"))
        XCTAssertNotEqual(Bo3Palette.hash("温迪"), Bo3Palette.hash("甘雨"))

        let hues = Bo3Palette.fallbackHues(seed: 0)
        XCTAssertEqual(hues.0, 0, accuracy: 0.0001)
        XCTAssertEqual(hues.1, 38.0 / 360.0, accuracy: 0.0001)
    }
}
