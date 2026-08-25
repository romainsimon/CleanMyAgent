import SwiftUI

struct PerformanceView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "Performance",
                    subtitle: "Comparable local observations with source-specific coverage."
                )

                VStack(spacing: 0) {
                    performanceHeader
                    Divider().overlay(Color.agentSpaceSeparator)
                    ForEach(Array(model.performance.metrics.enumerated()), id: \.element.id) { index, metric in
                        PerformanceRow(metric: metric, compact: false)
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

                VStack(alignment: .leading, spacing: 8) {
                    Label("How to read these numbers", systemImage: "info.circle")
                        .font(.headline)
                    Text("Observed output tok/s is not provider-side decoding speed. Tool execution, multiple model calls, local logging coverage, and each agent’s event format can affect the result.")
                        .font(.callout)
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .frame(maxWidth: 720, alignment: .leading)
                }
                .padding(.top, 2)
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }

    private var performanceHeader: some View {
        HStack {
            Text("Agent").frame(maxWidth: .infinity, alignment: .leading)
            Text("Observed tok/s").frame(width: 130, alignment: .trailing)
            Text("TTFT").frame(width: 105, alignment: .trailing)
            Text("Output tokens").frame(width: 125, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.agentSpaceSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct PerformanceRow: View {
    let metric: AgentMetric
    let compact: Bool

    var body: some View {
        HStack(spacing: 12) {
            AgentBadge(agent: metric.agent, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(metric.agent.rawValue)
                        .font(.body.weight(.medium))
                    Text(metric.model)
                        .font(.caption)
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .lineLimit(1)
                }
                Text(metric.coverage)
                    .font(.caption2)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .lineLimit(compact ? 1 : 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            metricValue(metric.observedTokensPerSecond.map { String(format: "%.1f", $0) }, suffix: "tok/s")
                .frame(width: 130, alignment: .trailing)

            if !compact {
                metricValue(metric.timeToFirstTokenMs.map { formatMilliseconds($0) }, suffix: nil)
                    .frame(width: 105, alignment: .trailing)
                metricValue(metric.outputTokens > 0 ? metric.outputTokens.formatted(.number.notation(.compactName)) : nil, suffix: nil)
                    .frame(width: 125, alignment: .trailing)
            }
        }
        .agentSpaceRow()
    }

    private func metricValue(_ value: String?, suffix: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value ?? "—")
                .font(.body.weight(.semibold))
                .monospacedDigit()
            if let suffix, value != nil {
                Text(suffix)
                    .font(.caption2)
                    .foregroundStyle(Color.agentSpaceSecondary)
            }
        }
    }

    private func formatMilliseconds(_ value: Double) -> String {
        value >= 1_000 ? String(format: "%.1fs", value / 1_000) : String(format: "%.0fms", value)
    }
}
