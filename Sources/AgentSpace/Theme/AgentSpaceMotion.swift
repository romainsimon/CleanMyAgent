import AppKit
import SwiftUI

enum AgentMotion {
    static let navigation = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
    static let chart = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.26)
    static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
    static let release = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.08)

    static func allowsAnimation(reduceMotion: Bool, keyboardInput: Bool) -> Bool {
        !reduceMotion && !keyboardInput
    }
}

private struct AgentMotionEnabledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var agentMotionEnabled: Bool {
        get { self[AgentMotionEnabledKey.self] }
        set { self[AgentMotionEnabledKey.self] = newValue }
    }
}

/// Tracks only the input method, never the key, coordinates or user content.
@MainActor
final class AgentInputMethod: ObservableObject {
    @Published private(set) var keyboardInput = false
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.keyboardInput = event.type == .keyDown }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

enum AgentChartAxis { case horizontal, vertical }

private struct AgentChartReveal: ViewModifier {
    @Environment(\.agentMotionEnabled) private var motionEnabled
    @State private var progress: CGFloat = 1
    let axis: AgentChartAxis

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: axis == .horizontal ? progress : 1,
                         y: axis == .vertical ? progress : 1, anchor: .bottomLeading)
            .opacity(0.5 + progress * 0.5)
            .task {
                guard motionEnabled else { return }
                settle(at: 0.08)
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                guard !Task.isCancelled, motionEnabled else { settle(at: 1); return }
                withAnimation(AgentMotion.chart) { progress = 1 }
            }
            .onChange(of: motionEnabled) {
                if !motionEnabled { settle(at: 1) }
            }
    }

    private func settle(at value: CGFloat) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { progress = value }
    }
}

extension View {
    /// Reveal only the chart plot; axes, domains and measured values stay stable.
    func agentChartReveal(axis: AgentChartAxis) -> some View {
        modifier(AgentChartReveal(axis: axis))
    }
}

struct AgentPressStyle: ButtonStyle {
    @Environment(\.agentMotionEnabled) private var motionEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(motionEnabled && configuration.isPressed ? 0.985 : 1)
            .animation(motionEnabled ? (configuration.isPressed ? AgentMotion.press : AgentMotion.release) : nil,
                       value: configuration.isPressed)
    }
}
