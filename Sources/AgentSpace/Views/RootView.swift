import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isSidebarVisible = true

    private var currentSection: AppSection {
        model.selectedSection ?? .overview
    }

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .frame(width: 212)

                Rectangle()
                    .fill(Color.agentSpaceSeparator)
                    .frame(width: 1)
            }

            ZStack {
                AgentSpaceBackground()
                detail(for: currentSection)
                    .id(currentSection)
            }
        }
        .tint(.agentSpaceBlue)
        .symbolRenderingMode(.hierarchical)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .accessibilityLabel(isSidebarVisible ? "Hide sidebar" : "Show sidebar")
                .help(isSidebarVisible ? "Hide sidebar" : "Show sidebar")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel(model.isScanning ? "Audit in progress" : "Refresh audit")
                .disabled(model.isScanning)
                .help("Refresh audit (⌘R)")
            }
        }
    }

    private func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("CleanMyAgent")
                        .font(.system(size: 14, weight: .semibold))
                    Text(model.isDemo && !model.isScreenshotMode ? "Demo data · cleanup disabled" : "Local agent care")
                        .font(.caption)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    SidebarGroup(
                        title: "Your Mac",
                        sections: [.overview, .cleanup, .worktrees, .storage],
                        selection: $model.selectedSection
                    )
                    SidebarGroup(
                        title: "Your agents",
                        sections: [.agents, .usage, .performance],
                        selection: $model.selectedSection
                    )
                    SidebarGroup(
                        title: "System",
                        sections: [.settings],
                        selection: $model.selectedSection
                    )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
            .minimalMacScrollbars()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(Color.agentSpaceBlue)
                    Text("You're in control")
                        .font(.caption.weight(.medium))
                }
                Text("Review first. Confirm each cleanup.")
                    .font(.caption)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background {
            ZStack {
                if !reduceTransparency {
                    Rectangle().fill(.regularMaterial)
                }
                Color.agentSpaceBackground.opacity(reduceTransparency ? 1 : 0.72)
            }
        }
    }

    @ViewBuilder
    private func detail(for section: AppSection) -> some View {
        switch section {
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

private struct SidebarGroup: View {
    let title: String
    let sections: [AppSection]
    @Binding var selection: AppSection?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.agentSpaceSecondary)
                .padding(.horizontal, 10)

            ForEach(sections) { section in
                SidebarItem(
                    section: section,
                    isSelected: selection == section
                ) {
                    selection = section
                }
            }
        }
    }
}

private struct SidebarItem: View {
    @State private var isHovered = false

    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isSelected ? Color.agentSpaceBlue : Color.agentSpaceSecondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.agentSpaceSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.agentSpaceBlue.opacity(0.14)
                        : Color.white.opacity(isHovered ? 0.045 : 0)
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(SidebarPressStyle())
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SidebarPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .semibold))
                .tracking(-0.55)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(Color.agentSpaceSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show CleanMyAgent Window") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        Divider()
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
        Button("Quit CleanMyAgent") {
            NSApplication.shared.terminate(nil)
        }
    }
}
