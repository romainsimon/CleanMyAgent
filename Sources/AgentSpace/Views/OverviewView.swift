import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "System overview",
                    subtitle: "Disk health, agent storage, and performance — measured locally."
                )
                diskStatus
                LiveSpeedMeterView(snapshot: model.liveSpeed)
                agentStorage
                performanceSummary
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .minimalMacScrollbars()
    }

    private var diskStatus: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(pressureColor.opacity(0.14))
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(pressureColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Macintosh HD")
                        .font(.headline)
                    Text(diskTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(pressureColor)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(model.disk.totalBytes > 0 ? usedPercentage : "—")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("used")
                        .font(.callout)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(model.disk.totalBytes > 0 ? ByteFormat.string(model.disk.freeBytes) : "Scanning…")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    if model.disk.totalBytes > 0 {
                        Text("free")
                            .font(.callout)
                            .foregroundStyle(Color.agentSpaceSecondary)
                    }
                }
            }

            MetricProgressTrack(fraction: usedFraction, color: pressureColor, height: 22)
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
                    color: Color.white.opacity(0.28),
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
        .padding(24)
        .agentSpacePanel(accent: pressureColor, cornerRadius: 22)
    }

    private var agentStorage: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                "Storage by agent",
                detail: model.disk.totalBytes > 0 ? "\(ByteFormat.string(model.totalAgentBytes)) observed" : "Measuring"
            )
            VStack(spacing: 0) {
                ForEach(Array(model.disk.agents.enumerated()), id: \.element.id) { index, storage in
                    AgentStorageRow(storage: storage, isScanning: model.isScanning && model.disk.totalBytes == 0)
                    if index < model.disk.agents.count - 1 {
                        Divider().overlay(Color.agentSpaceSeparator).padding(.leading, 56)
                    }
                }
            }
            .agentSpacePanel(accent: .agentSpaceBlue)
        }
    }

    private var performanceSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Observed performance", detail: "Local metadata")
            VStack(spacing: 0) {
                ForEach(Array(model.performance.metrics.enumerated()), id: \.element.id) { index, metric in
                    PerformanceRow(metric: metric, compact: true)
                    if index < model.performance.metrics.count - 1 {
                        Divider().overlay(Color.agentSpaceSeparator).padding(.leading, 56)
                    }
                }
            }
            .agentSpacePanel(accent: .agentSpaceViolet)
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
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
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
