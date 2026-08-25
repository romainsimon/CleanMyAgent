import AppKit
import SwiftUI

@MainActor
final class AgentSpaceAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            AgentSpaceWindowPresenter.shared.showRegisteredWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AgentSpaceWindowPresenter.shared.showRegisteredWindow()
        return true
    }
}

@main
@MainActor
struct AgentSpaceApp: App {
    @NSApplicationDelegateAdaptor(AgentSpaceAppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        AgentSpaceWindowPresenter.shared.register(model: model)
        DispatchQueue.main.async {
            AgentSpaceWindowPresenter.shared.show(model: model)
        }
    }

    var body: some Scene {
        Window("CleanMyAgent", id: "main") {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 940, minHeight: 620)
                .onAppear {
                    DispatchQueue.main.async {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        NSApplication.shared.windows
                            .filter { $0.canBecomeKey }
                            .forEach { $0.makeKeyAndOrderFront(nil) }
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Show CleanMyAgent Window") {
                    AgentSpaceWindowPresenter.shared.show(model: model)
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Refresh Audit") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.isScanning)
            }
        }

        MenuBarExtra {
            MenuBarSummaryView(model: model)
        } label: {
            Label(
                model.disk.totalBytes > 0 ? ByteFormat.string(model.disk.freeBytes) : "Scanning",
                systemImage: menuBarSymbol
            )
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarSymbol: String {
        switch model.disk.pressure {
        case .unknown: "internaldrive"
        case .healthy: "internaldrive"
        case .warning: "internaldrive.fill"
        case .critical: "exclamationmark.triangle.fill"
        }
    }
}
