import AppKit
import SwiftUI

@main
@MainActor
struct AgentSpaceApp: App {
    @StateObject private var model: AppModel

    init() {
        _model = StateObject(wrappedValue: AppModel())
    }

    var body: some Scene {
        WindowGroup("CleanMyAgent", id: "main") {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 940, minHeight: 620)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CleanMyAgentCommands(model: model)
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

struct CleanMyAgentCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Show CleanMyAgent Window") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("Refresh Audit") {
                Task { await model.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(model.isScanning)
        }
    }
}
