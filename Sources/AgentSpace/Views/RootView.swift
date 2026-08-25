import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentSection: AppSection {
        model.selectedSection ?? .overview
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 206, ideal: 222, max: 248)
        } detail: {
            ZStack {
                AgentSpaceBackground()
                detail(for: currentSection)
                    .id(currentSection)
                    .transition(
                        reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.99, anchor: .topLeading))
                    )
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: currentSection)
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
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel(model.isScanning ? "Audit in progress" : "Refresh audit")
                .disabled(model.isScanning)
                .help("Refresh audit (⌘R)")
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("CleanMyAgent")
                        .font(.headline.weight(.semibold))
                    Text("Local agent care")
                        .font(.caption2)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    SidebarGroup(
                        title: "Monitor",
                        sections: [.overview, .agents, .performance, .usage],
                        selection: $model.selectedSection
                    )
                    SidebarGroup(
                        title: "Maintain",
                        sections: [.storage, .worktrees, .cleanup],
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
                    StatusDot(color: .green)
                    Text("Protected cleanup")
                        .font(.caption.weight(.medium))
                }
                Text("Only revalidated targets can be cleaned.")
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
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.agentSpaceBackground.opacity(0.72)
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
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.agentSpaceBlue.opacity(0.22) : Color.white.opacity(0.055))
                    Image(systemName: section.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.agentSpaceBlue : Color.agentSpaceSecondary)
                }
                .frame(width: 27, height: 27)

                Text(section.rawValue)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.agentSpaceSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 38)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.agentSpaceBlue.opacity(0.13)
                        : Color.white.opacity(isHovered ? 0.045 : 0)
                    )
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.agentSpaceBlue.opacity(0.22), lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 29, weight: .semibold))
                .tracking(-0.55)
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
        Button("Show CleanMyAgent Window") {
            AgentSpaceWindowPresenter.shared.show(model: model)
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
