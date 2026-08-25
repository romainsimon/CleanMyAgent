import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(
                    title: "System overview",
                    subtitle: "Local agent storage and performance, without reading conversation content."
                )
                diskStatus
                agentStorage
                performanceSummary
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }

    private var diskStatus: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(diskTitle)
                        .font(.title2.weight(.semibold))
                    Text(model.disk.totalBytes > 0
                         ? "\(ByteFormat.string(model.disk.usedBytes)) used of \(ByteFormat.string(model.disk.totalBytes))"
                         : "Measuring disk capacity and agent data")
                        .font(.callout)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
                Spacer()
                Text(model.disk.totalBytes > 0 ? ByteFormat.string(model.disk.freeBytes) : "Scanning…")
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if model.disk.totalBytes > 0 {
                    Text("free")
                    .font(.callout)
                    .foregroundStyle(Color.agentSpaceSecondary)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(pressureColor)
                        .frame(width: max(4, proxy.size.width * model.disk.freeFraction))
                }
            }
            .frame(height: 7)
            .accessibilityLabel("Free disk space")
            .accessibilityValue("\(ByteFormat.string(model.disk.freeBytes)) free")

            HStack(spacing: 8) {
                StatusDot(color: pressureColor)
                Text(model.disk.pressure.rawValue)
                    .font(.caption.weight(.semibold))
                Text(model.disk.totalBytes > 0
                     ? "Last checked \(model.disk.capturedAt.formatted(date: .omitted, time: .shortened))"
                     : "Audit in progress")
                    .font(.caption)
                    .foregroundStyle(Color.agentSpaceSecondary)
            }
        }
        .padding(18)
        .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.agentSpaceSeparator, lineWidth: 1)
        }
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
            .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.agentSpaceSeparator, lineWidth: 1)
            }
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
            .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.agentSpaceSeparator, lineWidth: 1)
            }
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
