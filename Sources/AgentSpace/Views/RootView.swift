import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 208, max: 240)
        } detail: {
            detail
                .background(Color.agentSpaceBackground)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.isScanning)
                .help("Refresh audit (⌘R)")
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(AppSection.allCases, selection: $model.selectedSection) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
                    .padding(.vertical, 3)
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    StatusDot(color: .green)
                    Text("Protected cleanup")
                        .font(.caption.weight(.medium))
                }
                Text("Only reviewed targets can move to Trash.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.agentSpaceSeparator).frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedSection ?? .overview {
        case .overview: OverviewView(model: model)
        case .agents: AgentsView(model: model)
        case .performance: PerformanceView(model: model)
        case .usage: UsageView(model: model)
        case .storage: StorageView(model: model)
        case .worktrees: WorktreesView(model: model)
        case .cleanup: CleanView(model: model)
        case .settings: SettingsView(model: model)
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 25, weight: .semibold))
                .tracking(-0.35)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(Color.agentSpaceSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionTitle: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.agentSpaceSecondary)
            }
        }
    }
}

struct MenuBarSummaryView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Text("Agent Space")
        Text("\(ByteFormat.string(model.disk.freeBytes)) free")
        Text(model.liveSpeed.active
             ? "\(model.liveSpeed.observedTokensPerSecond.formatted(.number.precision(.fractionLength(1)))) tok/s · Codex live"
             : "No active Codex turn")
        Divider()
        ForEach(model.disk.agents) { agent in
            Text("\(agent.agent.rawValue): \(ByteFormat.string(agent.totalBytes))")
        }
        Divider()
        Button("Refresh Audit") {
            Task { await model.refresh() }
        }
        .disabled(model.isScanning)
        Button("Open Agent Space") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
        Divider()
        Button("Quit Agent Space") {
            NSApplication.shared.terminate(nil)
        }
    }
}
