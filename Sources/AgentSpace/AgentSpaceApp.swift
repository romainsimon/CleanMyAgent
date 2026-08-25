import SwiftUI

@main
struct AgentSpaceApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Agent Space") {
            RootView(model: model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 940, minHeight: 620)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .toolbar) {
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
        case .warning: "internaldrive.fill.trianglebadge.exclamationmark"
        case .critical: "exclamationmark.triangle.fill"
        }
    }
}
