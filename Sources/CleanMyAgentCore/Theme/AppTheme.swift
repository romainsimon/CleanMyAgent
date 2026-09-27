import AppKit
import SwiftUI

extension Color {
    static let cleanMyAgentBackground = AgentPalette.color(.background)
    static let cleanMyAgentSidebar = AgentPalette.color(.sidebar)
    static let cleanMyAgentSurface = AgentPalette.color(.surface)
    static let cleanMyAgentRaised = AgentPalette.color(.raised)
    static let cleanMyAgentText = AgentPalette.color(.text)
    static let cleanMyAgentSeparator = AgentPalette.color(.separator)
    static let cleanMyAgentSecondary = AgentPalette.color(.secondary)
    static let cleanMyAgentTrack = AgentPalette.color(.track)
    static let cleanMyAgentHover = AgentPalette.color(.hover)
    static let cleanMyAgentSelection = AgentPalette.color(.selection)
    static let cleanMyAgentAccent = AgentPalette.color(.accent)
    static let cleanMyAgentBlue = AgentPalette.color(.blue)
    static let cleanMyAgentGreen = AgentPalette.color(.green)
    static let cleanMyAgentAmber = AgentPalette.color(.amber)
    static let cleanMyAgentRed = AgentPalette.color(.red)
    static let cleanMyAgentViolet = AgentPalette.color(.violet)
    static let cleanMyAgentMagenta = AgentPalette.color(.magenta)

    static func agentAccent(_ agent: AgentKind) -> Color {
        AgentPalette.color(AgentPalette.agentRole(for: agent))
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
                PhosphorIcon(symbol: agent.symbol, size: size * 0.8)
                    .foregroundStyle(Color.agentAccent(agent))
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
    let fraction: Double
    let color: Color
    var height: CGFloat = 8

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
                        .agentChartReveal(axis: .horizontal)
                        .frame(width: min(availableWidth, max(4, availableWidth * clampedFraction)))
                }
                if hasTrailingSegment {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.cleanMyAgentTrack)
                        .frame(maxWidth: .infinity)
                }
            }
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
        scrollView.verticalScroller?.knobStyle = .default
        scrollView.verticalScroller?.controlSize = .small
        scrollView.horizontalScroller?.knobStyle = .default
        scrollView.horizontalScroller?.controlSize = .small
    }
}

extension View {
    func cleanMyAgentPanel(accent: Color = .cleanMyAgentBlue, cornerRadius: CGFloat = 18) -> some View {
        self
            .background(Color.cleanMyAgentSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.cleanMyAgentSeparator, lineWidth: 1)
            }
    }

    func cleanMyAgentRow() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
    }

    func minimalMacScrollbars() -> some View {
        background(MinimalMacScrollbarConfigurator().frame(width: 0, height: 0))
    }
}
