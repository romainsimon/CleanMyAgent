import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(
                    title: "A little room to breathe.",
                    subtitle: "Your disk, your agents, and the leftovers worth a look.",
                    illustration: "hero-mascot"
                )
                diskStatus
                nextSteps
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        agentStorage.frame(minWidth: 340, maxWidth: .infinity)
                        activity.frame(minWidth: 320, maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: 28) {
                        agentStorage
                        activity
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .minimalMacScrollbars()
    }

    private var diskStatus: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                AgentLabel("Macintosh HD", symbol: "internaldrive")
                    .font(.callout.weight(.medium))
                Spacer()
                AgentLabel(diskTitle, symbol: model.disk.pressure == .healthy ? "checkmark.circle" : "info.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(pressureColor)
            }
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(model.disk.totalBytes > 0 ? ByteFormat.string(model.disk.freeBytes) : "—")
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .tracking(-1)
                        .monospacedDigit()
                    Text("free")
                        .font(.callout)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.disk.totalBytes > 0 ? "\(usedPercentage) used" : "Measuring disk space…")
                        .font(.callout.weight(.medium)).monospacedDigit()
                    Text(model.disk.totalBytes > 0 ? "\(ByteFormat.string(model.disk.totalBytes)) capacity" : "Local audit")
                        .font(.caption).foregroundStyle(Color.agentSpaceSecondary)
                }
            }
            MetricProgressTrack(fraction: usedFraction, color: pressureColor, height: 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Disk space used")
                .accessibilityValue(model.disk.totalBytes > 0
                                    ? "\(usedPercentage), \(ByteFormat.string(model.disk.freeBytes)) free"
                                    : "Scanning")

            HStack(spacing: 22) {
                MetricLegendItem(
                    color: pressureColor,
                    label: "Used",
                    value: model.disk.totalBytes > 0 ? ByteFormat.string(model.disk.usedBytes) : "—"
                )
                MetricLegendItem(
                    color: Color.agentSpaceTrack,
                    label: "Free",
                    value: model.disk.totalBytes > 0 ? ByteFormat.string(model.disk.freeBytes) : "—"
                )
                Spacer()
                Text(model.disk.totalBytes > 0
                     ? "Checked \(model.disk.capturedAt.formatted(date: .omitted, time: .shortened))"
                     : "Audit in progress")
                    .font(.caption)
                    .foregroundStyle(Color.agentSpaceSecondary)
            }
        }
        .padding(22)
        .agentSpacePanel(cornerRadius: 18)
    }

    private var nextSteps: some View {
        HStack(spacing: 16) {
            reviewLink("Review worktrees", detail: "\(model.worktrees.filter { $0.safety == .removable }.count) verified for review", symbol: "arrow.triangle.branch", section: .worktrees)
            reviewLink("Review caches", detail: "Dependencies, caches & archives", symbol: "trash", section: .cleanup)
        }
    }

    private func reviewLink(_ title: String, detail: String, symbol: String, section: AppSection) -> some View {
        Button {
            model.selectedSection = section
        } label: {
            HStack(spacing: 12) {
                PhosphorIcon(symbol: symbol, size: 22).font(.system(size: 20)).foregroundStyle(Color.agentSpaceBlue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.callout.weight(.semibold)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(Color.agentSpaceSecondary)
                }
                Spacer(minLength: 0)
                PhosphorIcon(symbol: "chevron.right", size: 16).font(.caption).foregroundStyle(Color.agentSpaceSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(AgentPressStyle())
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionTitle("Right now", detail: "Local metadata")
            LiveSpeedMeterView(snapshot: model.liveSpeed, compact: true)
            performanceSummary
        }
    }

    private var agentStorage: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                "Storage by agent",
                detail: model.disk.totalBytes > 0 ? "\(ByteFormat.string(model.totalAgentBytes)) observed" : "Measuring"
            )
            VStack(spacing: 0) {
                ForEach(Array(displayedAgents.enumerated()), id: \.element.id) { index, storage in
                    AgentStorageRow(storage: storage, isScanning: model.isScanning && model.disk.totalBytes == 0)
                    if index < displayedAgents.count - 1 {
                        Divider().overlay(Color.agentSpaceSeparator).padding(.leading, 56)
                    }
                }
            }
            .agentSpacePanel(accent: .agentSpaceBlue)
            Button("View all \(model.disk.agents.count) agents") { model.selectedSection = .agents }
                .buttonStyle(.link)
                .font(.callout)
        }
    }

    private var displayedAgents: [AgentStorage] {
        Array(model.disk.agents.sorted { $0.totalBytes > $1.totalBytes }.prefix(4))
    }

    private var performanceSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Observed performance", detail: "Local metadata")
            VStack(spacing: 0) {
                ForEach(Array(model.performance.metrics.prefix(3).enumerated()), id: \.element.id) { index, metric in
                    PerformanceRow(metric: metric, compact: true)
                    if index < min(3, model.performance.metrics.count) - 1 {
                        Divider().overlay(Color.agentSpaceSeparator).padding(.leading, 56)
                    }
                }
            }
            .agentSpacePanel(accent: .agentSpaceViolet)
            Button("View performance & coverage") { model.selectedSection = .performance }
                .buttonStyle(.link)
                .font(.callout)
        }
    }

    private var diskTitle: String {
        switch model.disk.pressure {
        case .unknown: "Scanning local agent data"
        case .healthy: "Disk space is healthy"
        case .warning: "Disk space is running low"
        case .critical: "Disk space is critically low"
        }
    }

    private var usedFraction: Double {
        guard model.disk.totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(model.disk.usedBytes) / Double(model.disk.totalBytes)))
    }

    private var usedPercentage: String {
        "\(Int((usedFraction * 100).rounded()))%"
    }

    private var pressureColor: Color {
        switch model.disk.pressure {
        case .unknown: .secondary
        case .healthy: Color.agentSpaceGreen
        case .warning: Color.agentSpaceAmber
        case .critical: Color.agentSpaceRed
        }
    }
}

struct AgentStorageRow: View {
    let storage: AgentStorage
    var isScanning = false

    var body: some View {
        HStack(spacing: 12) {
            AgentBadge(agent: storage.agent, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(storage.agent.rawValue)
                    .font(.body.weight(.medium))
                Text(isScanning ? "Measuring local data…" : storage.isInstalled ? storage.rootPath.replacingOccurrences(of: NSHomeDirectory(), with: "~") : "Not installed")
                    .font(.caption)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(isScanning ? "—" : ByteFormat.string(storage.totalBytes))
                .font(.body.weight(.medium))
                .monospacedDigit()
        }
        .agentSpaceRow()
    }
}
