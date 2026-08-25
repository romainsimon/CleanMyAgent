import AppKit
import SwiftUI

extension Color {
    static let agentSpaceBackground = Color(nsColor: NSColor(calibratedWhite: 0.055, alpha: 1))
    static let agentSpaceSurface = Color(nsColor: NSColor(calibratedWhite: 0.085, alpha: 1))
    static let agentSpaceRaised = Color(nsColor: NSColor(calibratedWhite: 0.115, alpha: 1))
    static let agentSpaceSeparator = Color.white.opacity(0.09)
    static let agentSpaceSecondary = Color.white.opacity(0.58)

    static func agentAccent(_ agent: AgentKind) -> Color {
        switch agent {
        case .codex: Color(red: 0.38, green: 0.70, blue: 1.00)
        case .claude: Color(red: 0.91, green: 0.56, blue: 0.37)
        case .grok: Color(red: 0.69, green: 0.58, blue: 1.00)
        }
    }
}

struct AgentBadge: View {
    let agent: AgentKind
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let image = iconImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .fill(Color.agentAccent(agent).opacity(0.16))
                    Image(systemName: agent.symbol)
                        .font(.system(size: size * 0.45, weight: .semibold))
                        .foregroundStyle(Color.agentAccent(agent))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var iconImage: NSImage? {
        if let resourceURL = Bundle.main.resourceURL {
            let packagedURL = resourceURL
                .appendingPathComponent("AgentSpace_AgentSpace.bundle", isDirectory: true)
                .appendingPathComponent("\(agent.iconResourceName).png")
            if let image = NSImage(contentsOf: packagedURL) { return image }
        }
        guard let developmentURL = Bundle.module.url(
            forResource: agent.iconResourceName,
            withExtension: "png"
        ) else { return nil }
        return NSImage(contentsOf: developmentURL)
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }
}

extension View {
    func agentSpaceRow() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
    }
}
