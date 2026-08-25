import AppKit
import SwiftUI

@MainActor
final class AgentSpaceWindowPresenter {
    static let shared = AgentSpaceWindowPresenter()

    private weak var model: AppModel?
    private var windowController: NSWindowController?

    func register(model: AppModel) {
        self.model = model
    }

    func showRegisteredWindow() {
        guard let model else { return }
        show(model: model)
    }

    func show(model: AppModel) {
        NSApplication.shared.setActivationPolicy(.regular)

        if let existingWindow = NSApplication.shared.windows.first(where: {
            $0.canBecomeKey
                && $0.isVisible
                && $0.level == .normal
                && $0.frame.width >= 600
                && $0.frame.height >= 400
        }) {
            existingWindow.makeKeyAndOrderFront(nil)
            existingWindow.orderFrontRegardless()
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let content = RootView(model: model)
            .preferredColorScheme(.dark)
            .frame(minWidth: 940, minHeight: 620)
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 80, width: 940, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CleanMyAgent"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
        window.setFrameAutosaveName("CleanMyAgentMainWindow")
        window.contentView = NSHostingView(rootView: content)

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
