import SwiftUI

struct Bo3ColorValue: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

enum Bo3Palette {
    static let teamA = Bo3ColorValue(hex: 0xFF5F70)
    static let teamB = Bo3ColorValue(hex: 0xB18CFF)
    static let teamAInk = Bo3ColorValue(hex: 0xD93F4B)
    static let teamBInk = Bo3ColorValue(hex: 0x7C4DFF)
    static let gold = Bo3ColorValue(hex: 0xF2C86B)
    static let goldInk = Bo3ColorValue(hex: 0x9A6B16)

    private static let roleValues: [String: Bo3ColorValue] = [
        "射手": Bo3ColorValue(hex: 0xF2C86B),
        "打野": Bo3ColorValue(hex: 0x4ADE80),
        "中路": Bo3ColorValue(hex: 0xA78BFA),
        "战士": Bo3ColorValue(hex: 0xFB7185),
        "辅助": Bo3ColorValue(hex: 0x38BDF8),
        "坦克": Bo3ColorValue(hex: 0xFBBF24),
    ]

    private static let extraRoleValues: [Bo3ColorValue] = [
        Bo3ColorValue(hex: 0x38BDF8),
        Bo3ColorValue(hex: 0xF472B6),
        Bo3ColorValue(hex: 0xFBBF24),
        Bo3ColorValue(hex: 0x34D399),
        Bo3ColorValue(hex: 0xA78BFA),
        Bo3ColorValue(hex: 0xFB923C),
        Bo3ColorValue(hex: 0x60A5FA),
        Bo3ColorValue(hex: 0xE879F9),
        Bo3ColorValue(hex: 0x2DD4BF),
        Bo3ColorValue(hex: 0xF87171),
    ]

    private static let elementValues: [String: Bo3ColorValue] = [
        "风": Bo3ColorValue(hex: 0x7AD7B5),
        "火": Bo3ColorValue(hex: 0xFF8B6B),
        "水": Bo3ColorValue(hex: 0x59B9FF),
        "冰": Bo3ColorValue(hex: 0xA9E8FF),
        "雷": Bo3ColorValue(hex: 0xC6A3FF),
        "岩": Bo3ColorValue(hex: 0xF0C96F),
        "草": Bo3ColorValue(hex: 0x93DC72),
    ]

    static func teamValue(_ team: Bo3Team) -> Bo3ColorValue {
        team == .a ? teamA : teamB
    }

    static func teamColor(_ team: Bo3Team) -> Color {
        teamValue(team).color
    }

    static func teamInkValue(_ team: Bo3Team) -> Bo3ColorValue {
        team == .a ? teamAInk : teamBInk
    }

    static func teamInkColor(_ team: Bo3Team) -> Color {
        teamInkValue(team).color
    }

    static func roleValue(for role: String) -> Bo3ColorValue {
        if let value = roleValues[role] { return value }
        let index = Int(hash(role) % UInt32(extraRoleValues.count))
        return extraRoleValues[index]
    }

    static func roleColor(for role: String) -> Color {
        roleValue(for: role).color
    }

    static func elementValue(for element: String?) -> Bo3ColorValue? {
        guard let element, !element.isEmpty else { return nil }
        return elementValues[element]
    }

    static func elementColor(for element: String?) -> Color {
        elementValue(for: element)?.color ?? Color.white.opacity(0.22)
    }

    static func hash(_ string: String) -> UInt32 {
        var hash: Int32 = 0
        for scalar in string.unicodeScalars {
            hash = (hash &* 31) &+ Int32(truncatingIfNeeded: scalar.value)
        }
        return UInt32(bitPattern: hash)
    }

    static func fallbackHues(seed: UInt32) -> (Double, Double) {
        let first = Double(seed % 360) / 360
        let second = Double((seed + 38) % 360) / 360
        return (first, second)
    }

    static func fallbackColors(seed: UInt32) -> (Color, Color) {
        let hues = fallbackHues(seed: seed)
        return (
            Color(hue: hues.0, saturation: 0.58, brightness: 0.44),
            Color(hue: hues.1, saturation: 0.62, brightness: 0.24)
        )
    }
}
