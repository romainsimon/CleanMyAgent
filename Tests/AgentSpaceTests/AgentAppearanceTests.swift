import AppKit
import SwiftUI
import XCTest
@testable import AgentSpace

final class AgentAppearanceTests: XCTestCase {
    func testSystemPreferenceAndSavedAppearance() {
        XCTAssertNil(AgentAppearance.system.colorScheme)
        XCTAssertEqual(AgentAppearance.light.colorScheme, .light)
        XCTAssertEqual(AgentAppearance.dark.colorScheme, .dark)
        let suite = "CleanMyAgentAppearanceTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(defaults.string(forKey: AgentAppearance.preferenceKey))
        defaults.set(AgentAppearance.light.rawValue, forKey: AgentAppearance.preferenceKey)
        let reopened = UserDefaults(suiteName: suite)!
        XCTAssertEqual(AgentAppearance(rawValue: reopened.string(forKey: AgentAppearance.preferenceKey)!), .light)
    }

    func testReadableRolesInBothAppearances() {
        for dark in [false, true] {
            for surface in [AgentColorRole.background, .sidebar, .surface, .raised, .selection] {
                for text in [AgentColorRole.text, .secondary] {
                    XCTAssertGreaterThanOrEqual(contrast(AgentPalette.hex(text, dark: dark), AgentPalette.hex(surface, dark: dark)), 4.5,
                                                "\(text) on \(surface), dark=\(dark)")
                }
            }
            for semantic in [AgentColorRole.accent, .blue, .green, .amber, .red] {
                for surface in [AgentColorRole.background, .surface, .selection] {
                    XCTAssertGreaterThanOrEqual(contrast(AgentPalette.hex(semantic, dark: dark), AgentPalette.hex(surface, dark: dark)), 4.5,
                                                "\(semantic) on \(surface), dark=\(dark)")
                }
            }
        }
    }

    func testNativeColorsResolveAgainstAppearance() {
        let color = NSColor(name: nil) { appearance in
            NSColor(rgb: AgentPalette.hex(.background, dark: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua))
        }
        var light: CGFloat = 0
        var dark: CGFloat = 0
        NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
            light = color.usingColorSpace(.sRGB)!.redComponent
        }
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
            dark = color.usingColorSpace(.sRGB)!.redComponent
        }
        XCTAssertGreaterThan(light, 0.9)
        XCTAssertLessThan(dark, 0.1)
    }

    private func contrast(_ foreground: UInt32, _ background: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            let components = [Double((hex >> 16) & 255) / 255, Double((hex >> 8) & 255) / 255, Double(hex & 255) / 255]
            let c = components.map { value -> Double in
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return c[0] * 0.2126 + c[1] * 0.7152 + c[2] * 0.0722
        }
        let a = luminance(foreground), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
