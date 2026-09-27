import AppKit
import SwiftUI

enum AgentColorRole: CaseIterable {
    case background, sidebar, surface, raised, text, secondary, separator, track, hover, selection
    case accent, blue, green, amber, red, violet, magenta, teal, gold, clay, gray, indigo
}

enum AgentPalette {
    // Each appearance is composed independently. Status colors always accompany a written reason.
    static func hex(_ role: AgentColorRole, dark: Bool) -> UInt32 {
        switch (role, dark) {
        case (.background, false): 0xf7f7f5
        case (.background, true): 0x151619
        case (.sidebar, false): 0xeeefed
        case (.sidebar, true): 0x191b1f
        case (.surface, false): 0xffffff
        case (.surface, true): 0x1e2024
        case (.raised, false): 0xeceeea
        case (.raised, true): 0x292c31
        case (.text, false): 0x252832
        case (.text, true): 0xf0f1f3
        case (.secondary, false): 0x5b616a
        case (.secondary, true): 0xb0b4bc
        case (.separator, false): 0xdfe2de
        case (.separator, true): 0x35383f
        case (.track, false): 0xd6dcd6
        case (.track, true): 0x42464e
        case (.hover, false): 0xe4e6e2
        case (.hover, true): 0x292c31
        case (.selection, false): 0xf4e3dc
        case (.selection, true): 0x3b2b29
        case (.accent, false): 0xa83d2c
        case (.accent, true): 0xff927a
        case (.blue, false): 0x2565ac
        case (.blue, true): 0x88b8f3
        case (.green, false): 0x24734d
        case (.green, true): 0x79d8a5
        case (.amber, false): 0x8d580c
        case (.amber, true): 0xf2c579
        case (.red, false): 0xaa3438
        case (.red, true): 0xff9699
        case (.violet, false): 0x7350b0
        case (.violet, true): 0xbca1f3
        case (.magenta, false): 0xa33c76
        case (.magenta, true): 0xeb96c1
        case (.teal, false): 0x167969
        case (.teal, true): 0x78d6c0
        case (.gold, false): 0x956713
        case (.gold, true): 0xe9c774
        case (.clay, false): 0xa34f2d
        case (.clay, true): 0xeab190
        case (.gray, false): 0x5e6979
        case (.gray, true): 0xc0c7d1
        case (.indigo, false): 0x535db5
        case (.indigo, true): 0xaaaef3
        }
    }

    static func color(_ role: AgentColorRole) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(rgb: hex(role, dark: dark))
        })
    }
}

extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(srgbRed: Double((rgb >> 16) & 255) / 255,
                  green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255, alpha: 1)
    }
}

extension Color {
    init(_ rgb: UInt32) { self.init(nsColor: NSColor(rgb: rgb)) }
}
