import AppKit
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var inputMethod = AgentInputMethod()
    @Namespace private var navigationSelection
    @State private var isSidebarVisible = true

    private var currentSection: AppSection {
        model.selectedSection ?? .overview
    }

    private var motionEnabled: Bool {
        AgentMotion.allowsAnimation(
            reduceMotion: reduceMotion || ProcessInfo.processInfo.arguments.contains("--reduce-motion"),
            keyboardInput: inputMethod.keyboardInput
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .frame(width: 212)
                    .animation(motionEnabled ? AgentMotion.navigation : nil, value: currentSection)

                Rectangle()
                    .fill(Color.cleanMyAgentSeparator)
                    .frame(width: 1)
            }

            ZStack {
                AppBackground()
                detail(for: currentSection)
                    .id(currentSection)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity))
            }
            .animation(motionEnabled ? AgentMotion.navigation : nil, value: currentSection)
        }
        .environment(\.agentMotionEnabled, motionEnabled)
        .onAppear { inputMethod.start() }
        .onDisappear { inputMethod.stop() }
        .foregroundStyle(Color.cleanMyAgentText)
        .tint(.cleanMyAgentAccent)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    SidebarGroup(
                        title: "Your Mac",
                        sections: [.overview, .cleanup, .worktrees, .storage],
                        selection: $model.selectedSection, namespace: navigationSelection
                    )
                    SidebarGroup(
                        title: "Your agents",
                        sections: [.agents, .usage, .performance],
                        selection: $model.selectedSection, namespace: navigationSelection
                    )
                    SidebarGroup(
                        title: "System",
                        sections: [.settings],
                        selection: $model.selectedSection, namespace: navigationSelection
                    )
                }
                .padding(.horizontal, 10)
                .padding(.top, 22)
                .padding(.bottom, 16)
            }
            .minimalMacScrollbars()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    PhosphorIcon(symbol: "checkmark.shield")
                        .foregroundStyle(Color.cleanMyAgentBlue)
                    Text("You're in control")
                        .font(.caption.weight(.medium))
                }
                Text(model.isDemo && !model.isScreenshotMode ? "Demo data · cleanup disabled" : "Review first. Confirm each cleanup.")
                    .font(.caption)
                    .foregroundStyle(Color.cleanMyAgentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            AppearanceSwitcher()
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
        }
        .background {
            ZStack {
                if !reduceTransparency {
                    Rectangle().fill(.regularMaterial)
                }
                Color.cleanMyAgentSidebar.opacity(reduceTransparency ? 1 : 0.92)
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
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.cleanMyAgentSecondary)
                .padding(.horizontal, 10)

            ForEach(sections) { section in
                SidebarItem(
                    section: section,
                    isSelected: selection == section, namespace: namespace
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
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                PhosphorIcon(symbol: section.symbol, size: 22)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isSelected ? Color.cleanMyAgentAccent : Color.cleanMyAgentSecondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.cleanMyAgentAccent : Color.cleanMyAgentSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.cleanMyAgentHover.opacity(isHovered && !isSelected ? 1 : 0))
                if isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.cleanMyAgentSelection)
                        .matchedGeometryEffect(id: "navigation-selection", in: namespace)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(AgentPressStyle())
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    var illustration: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-0.55)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Color.cleanMyAgentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let illustration { AgentIllustration(name: illustration) }
        }
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
                    .foregroundStyle(Color.cleanMyAgentSecondary)
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
