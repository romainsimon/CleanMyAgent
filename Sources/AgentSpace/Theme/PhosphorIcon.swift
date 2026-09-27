import SwiftUI

/// Official Phosphor Core 2.1.1 Duotone glyphs. Template alpha preserves the 20% secondary layer.
struct PhosphorIcon: View {
    let name: String
    var size: CGFloat = 18

    init(_ name: String, size: CGFloat = 18) { self.name = name; self.size = size }
    init(symbol: String, size: CGFloat = 18) { self.init(Self.glyph(for: symbol), size: size) }

    var body: some View {
        Group {
            if let image = AppResources.duotoneIcon(named: name, pointSize: size) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable().interpolation(.high).scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    nonisolated static func glyph(for symbol: String) -> String {
        switch symbol {
        case "square.grid.2x2": "squares-four"
        case "cpu", "terminal": "robot"
        case "speedometer", "gauge.with.dots.needle.50percent": "gauge"
        case "chart.xyaxis.line": "chart-bar"
        case "internaldrive", "externaldrive.badge.checkmark": "hard-drives"
        case "arrow.triangle.branch", "arrow.trianglehead.branch": "git-branch"
        case "trash.slash", "trash": "trash"
        case "gearshape": "gear-six"
        case "checkmark.shield", "lock.shield": "shield-check"
        case "lock": "lock-key"
        case "checkmark.circle", "checkmark.circle.fill": "check-circle"
        case "info.circle": "info"
        case "shippingbox": "package"
        case "archivebox": "archive"
        case "person.crop.circle": "user-circle"
        case "clock": "clock"
        case "network": "globe"
        case "text.badge.xmark", "doc.text": "file-text"
        case "text.bubble": "chat-circle-text"
        case "puzzlepiece.extension": "puzzle-piece"
        case "arrow.triangle.2.circlepath": "arrows-clockwise"
        case "exclamationmark.triangle.fill", "app.badge.checkmark": "warning"
        case "chevron.right": "caret-right"
        default: "folder"
        }
    }
}

struct AgentLabel: View {
    let title: String
    let symbol: String

    init(_ title: String, symbol: String) { self.title = title; self.symbol = symbol }

    var body: some View {
        Label { Text(title) } icon: { PhosphorIcon(symbol: symbol, size: 16) }
    }
}

struct AgentIllustration: View {
    let name: String
    var size: CGFloat = 80

    var body: some View {
        Group {
            if let image = AppResources.image(named: name) {
                Image(nsImage: image)
                    .resizable().interpolation(.high).scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
