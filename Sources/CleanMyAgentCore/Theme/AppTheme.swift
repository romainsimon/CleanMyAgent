import AppKit
import SwiftUI

extension Color {
    static let cleanMyAgentBackground = Color(red: 0.025, green: 0.032, blue: 0.070)
    static let cleanMyAgentSurface = Color(red: 0.060, green: 0.070, blue: 0.125)
    static let cleanMyAgentRaised = Color(red: 0.095, green: 0.105, blue: 0.175)
    static let cleanMyAgentSeparator = Color.white.opacity(0.105)
    static let cleanMyAgentSecondary = Color.white.opacity(0.64)
    static let cleanMyAgentBlue = Color(red: 0.30, green: 0.58, blue: 1.00)
    static let cleanMyAgentViolet = Color(red: 0.57, green: 0.42, blue: 1.00)
    static let cleanMyAgentMagenta = Color(red: 0.94, green: 0.36, blue: 0.73)

    static func agentAccent(_ agent: AgentKind) -> Color {
        switch agent {
        case .codex: Color(red: 0.38, green: 0.70, blue: 1.00)
        case .claude: Color(red: 0.91, green: 0.56, blue: 0.37)
        case .grok: Color(red: 0.69, green: 0.58, blue: 1.00)
        case .cursor: Color(red: 0.72, green: 0.75, blue: 0.82)
        case .hermes: Color(red: 0.34, green: 0.78, blue: 0.67)
        case .openCode: Color(red: 0.96, green: 0.78, blue: 0.28)
        case .ori: Color(red: 0.59, green: 0.66, blue: 1.00)
        case .kiloCode: Color(red: 0.92, green: 0.39, blue: 0.63)
        }
    }
}

struct AppBackground: View {
    var body: some View {
        Color.cleanMyAgentBackground
        .ignoresSafeArea()
        .accessibilityHidden(true)
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

    private var iconImage: NSImage? { AppResources.icon(for: agent) }

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

struct MetricProgressTrack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let fraction: Double
    let color: Color
    var height: CGFloat = 20

    var body: some View {
        GeometryReader { proxy in
            let clampedFraction = CGFloat(min(1, max(0, fraction)))
            let hasLeadingSegment = clampedFraction > 0
            let hasTrailingSegment = clampedFraction < 1
            let gap: CGFloat = hasLeadingSegment && hasTrailingSegment ? 4 : 0
            let availableWidth = max(0, proxy.size.width - gap)

            HStack(spacing: gap) {
                if hasLeadingSegment {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color)
                        .frame(width: min(availableWidth, max(4, availableWidth * clampedFraction)))
                }
                if hasTrailingSegment {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(maxWidth: .infinity)
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: fraction)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct MetricLegendItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(label)
                .foregroundStyle(Color.cleanMyAgentSecondary)
            Text(value)
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .font(.callout)
    }
}

private struct MinimalMacScrollbarConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = MinimalMacScrollbarProbe()
        view.configureWhenReady()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MinimalMacScrollbarProbe)?.configureWhenReady()
    }
}

private final class MinimalMacScrollbarProbe: NSView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureWhenReady()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWhenReady()
    }

    func configureWhenReady() {
        DispatchQueue.main.async { [weak self] in
            self?.configureScrollView()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.configureScrollView()
        }
    }

    private func configureScrollView() {
        guard let scrollView = enclosingScrollView else { return }
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.usesPredominantAxisScrolling = true
        scrollView.verticalScroller?.knobStyle = .light
        scrollView.verticalScroller?.controlSize = .small
        scrollView.horizontalScroller?.knobStyle = .light
        scrollView.horizontalScroller?.controlSize = .small
    }
}

extension View {
    func cleanMyAgentPanel(accent: Color = .cleanMyAgentBlue, cornerRadius: CGFloat = 18) -> some View {
        self
            .background(Color.cleanMyAgentSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.13), lineWidth: 1)
            }
    }

    func cleanMyAgentRow() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
    }

    func minimalMacScrollbars() -> some View {
        background(MinimalMacScrollbarConfigurator().frame(width: 0, height: 0))
    }
}
