import Charts
import SwiftUI

struct UsageView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    PageHeader(
                        title: "Usage",
                        subtitle: "Local token activity across agents, inspired by ccusage and rendered as native charts."
                    )
                    rangePicker
                }

                if (model.isUsageScanning || model.isScanning) && model.usage.buckets.isEmpty {
                    loadingState
                } else if model.usage.buckets.isEmpty {
                    emptyState
                } else {
                    summaryStrip
                    activityChart

                    HStack(alignment: .top, spacing: 18) {
                        compositionChart
                        modelChart
                    }

                    dailyTable
                    coveragePanel
                }
            }
            .padding(28)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .onChange(of: model.usageRange) {
            Task { await model.refreshUsage() }
        }
    }

    private var rangePicker: some View {
        Picker("Usage range", selection: $model.usageRange) {
            ForEach(UsageRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 210)
        .disabled(model.isUsageScanning)
        .accessibilityLabel("Usage history range")
    }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            summaryMetric("Total tokens", value: compact(model.usage.totalTokens))
            metricDivider
            summaryMetric("Output", value: compact(model.usage.outputTokens))
            metricDivider
            summaryMetric("Cache read", value: compact(model.usage.cacheReadTokens))
            metricDivider
            summaryMetric("Sessions", value: model.usage.sessionCount.formatted())
        }
        .padding(.vertical, 16)
        .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.agentSpaceSeparator, lineWidth: 1)
        }
    }

    private func summaryMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.agentSpaceSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.agentSpaceSeparator)
            .frame(width: 1, height: 40)
    }

    private var activityChart: some View {
        chartSurface(title: "Token activity", detail: model.usage.range.title) {
            Chart(model.usage.buckets) { bucket in
                BarMark(
                    x: .value("Day", bucket.date, unit: .day),
                    y: .value("Tokens", bucket.totalTokens)
                )
                .foregroundStyle(by: .value("Agent", bucket.agent.rawValue))
            }
            .chartForegroundStyleScale([
                "Codex": Color.agentAccent(.codex),
                "Claude Code": Color.agentAccent(.claude),
                "Grok": Color.agentAccent(.grok)
            ])
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: model.usageRange == .sevenDays ? 7 : 8)) { value in
                    AxisGridLine().foregroundStyle(Color.agentSpaceSeparator)
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.agentSpaceSeparator)
                    AxisValueLabel {
                        if let tokens = value.as(Int64.self) { Text(compact(tokens)) }
                    }
                    .foregroundStyle(Color.agentSpaceSecondary)
                }
            }
            .chartLegend(position: .top, alignment: .leading, spacing: 16)
            .chartXScale(range: .plotDimension(startPadding: 8, endPadding: 28))
            .frame(height: 270)
            .accessibilityLabel("Daily token activity by agent")
        }
    }

    private var compositionChart: some View {
        chartSurface(title: "Token composition", detail: "No double counting") {
            Chart(tokenParts) { part in
                BarMark(
                    x: .value("Category", part.name),
                    y: .value("Tokens", part.tokens)
                )
                .foregroundStyle(by: .value("Category", part.name))
            }
            .chartForegroundStyleScale([
                "Uncached input": Color(red: 0.38, green: 0.70, blue: 1.00),
                "Cache read": Color(red: 0.32, green: 0.78, blue: 0.65),
                "Cache write": Color(red: 0.76, green: 0.64, blue: 0.28),
                "Visible output": Color(red: 0.69, green: 0.58, blue: 1.00),
                "Reasoning": Color(red: 0.91, green: 0.56, blue: 0.37)
            ])
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label).lineLimit(2)
                        }
                    }
                    .foregroundStyle(Color.agentSpaceSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Color.agentSpaceSeparator)
                    AxisValueLabel {
                        if let tokens = value.as(Int64.self) { Text(compact(tokens)) }
                    }
                    .foregroundStyle(Color.agentSpaceSecondary)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 230)
            .accessibilityLabel("Token category composition")
        }
        .frame(maxWidth: .infinity)
    }

    private var modelChart: some View {
        chartSurface(title: "Top models", detail: "By total tokens") {
            Chart(topModels) { item in
                BarMark(
                    x: .value("Tokens", item.tokens),
                    y: .value("Model", item.label)
                )
                .foregroundStyle(Color.agentAccent(item.agent))
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Color.agentSpaceSeparator)
                    AxisValueLabel {
                        if let tokens = value.as(Int64.self) { Text(compact(tokens)) }
                    }
                    .foregroundStyle(Color.agentSpaceSecondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label).lineLimit(1)
                        }
                    }
                    .foregroundStyle(Color.agentSpaceSecondary)
                }
            }
            .frame(height: 230)
            .accessibilityLabel("Top models by token usage")
        }
        .frame(maxWidth: .infinity)
    }

    private var dailyTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Daily report", detail: "Newest first")
            VStack(spacing: 0) {
                dailyHeader
                Divider().overlay(Color.agentSpaceSeparator)
                ForEach(Array(dayRows.prefix(14).enumerated()), id: \.element.id) { index, day in
                    dayRow(day)
                    if index < min(dayRows.count, 14) - 1 {
                        Divider().overlay(Color.agentSpaceSeparator).padding(.leading, 14)
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

    private var dailyHeader: some View {
        HStack {
            Text("Date").frame(maxWidth: .infinity, alignment: .leading)
            Text("Input").frame(width: 110, alignment: .trailing)
            Text("Output").frame(width: 110, alignment: .trailing)
            Text("Cache read").frame(width: 110, alignment: .trailing)
            Text("Total").frame(width: 110, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.agentSpaceSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func dayRow(_ day: DayUsage) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.body.weight(.medium))
                HStack(spacing: 4) {
                    ForEach(day.agents) { agent in
                        AgentBadge(agent: agent, size: 18)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            tableNumber(day.input).frame(width: 110, alignment: .trailing)
            tableNumber(day.output).frame(width: 110, alignment: .trailing)
            tableNumber(day.cacheRead).frame(width: 110, alignment: .trailing)
            tableNumber(day.total).frame(width: 110, alignment: .trailing)
        }
        .agentSpaceRow()
    }

    private func tableNumber(_ value: Int64) -> some View {
        Text(compact(value))
            .font(.body.weight(.medium))
            .monospacedDigit()
    }

    private var coveragePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                StatusDot(color: model.usage.hasPartialCoverage ? .orange : .green)
                Text(model.usage.hasPartialCoverage ? "Partial local coverage" : "Local coverage complete within the selected bounds")
                    .font(.headline)
            }
            ForEach(model.usage.coverage) { coverage in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    AgentBadge(agent: coverage.agent, size: 20)
                    Text(coverage.agent.rawValue)
                        .font(.callout.weight(.medium))
                        .frame(width: 90, alignment: .leading)
                    Text("\(coverage.filesScanned) of \(coverage.filesDiscovered) files")
                        .font(.caption.monospacedDigit())
                        .frame(width: 120, alignment: .leading)
                    if coverage.truncatedFiles > 0 {
                        Text("\(coverage.truncatedFiles) tail-sampled")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(width: 110, alignment: .leading)
                    }
                    Text(coverage.note)
                        .font(.caption)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
            }
            Text("Only numeric usage, timestamps, model identifiers, and opaque session boundaries are aggregated. Estimated cost is intentionally omitted until Agent Space has a versioned pricing catalog.")
                .font(.caption)
                .foregroundStyle(Color.agentSpaceSecondary)
                .padding(.top, 2)
        }
        .padding(16)
        .background(Color.agentSpaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Scanning local numeric usage metadata…")
                .foregroundStyle(Color.agentSpaceSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.agentSpaceSecondary)
            Text("No usage found for this period")
                .font(.headline)
            Text("Refresh after a Codex, Claude Code, or Grok session produces local numeric metadata.")
                .font(.callout)
                .foregroundStyle(Color.agentSpaceSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chartSurface<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title, detail: detail)
            content()
        }
        .padding(16)
        .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.agentSpaceSeparator, lineWidth: 1)
        }
    }

    private var tokenParts: [TokenPart] {
        let uncached = max(0, model.usage.inputTokens - model.usage.cacheReadTokens - model.usage.cacheWriteTokens)
        let visibleOutput = max(0, model.usage.outputTokens - model.usage.reasoningTokens)
        return [
            TokenPart(name: "Uncached input", tokens: uncached),
            TokenPart(name: "Cache read", tokens: model.usage.cacheReadTokens),
            TokenPart(name: "Cache write", tokens: model.usage.cacheWriteTokens),
            TokenPart(name: "Visible output", tokens: visibleOutput),
            TokenPart(name: "Reasoning", tokens: model.usage.reasoningTokens)
        ].filter { $0.tokens > 0 }
    }

    private var topModels: [ModelChartItem] {
        model.usage.models.prefix(8).map {
            ModelChartItem(agent: $0.agent, label: shortModelLabel($0), tokens: $0.totalTokens)
        }
    }

    private var dayRows: [DayUsage] {
        Dictionary(grouping: model.usage.buckets, by: \.date)
            .map { date, buckets in
                DayUsage(
                    date: date,
                    agents: buckets.filter { $0.totalTokens > 0 }.map(\.agent).sorted { $0.rawValue < $1.rawValue },
                    input: buckets.reduce(0) { $0 + $1.inputTokens },
                    output: buckets.reduce(0) { $0 + $1.outputTokens },
                    cacheRead: buckets.reduce(0) { $0 + $1.cacheReadTokens }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func shortModelLabel(_ usage: ModelUsage) -> String {
        let model = usage.model.count > 22 ? String(usage.model.prefix(21)) + "…" : usage.model
        return "\(usage.agent.rawValue) · \(model)"
    }

    private func compact(_ value: Int64) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}

private struct TokenPart: Identifiable {
    let name: String
    let tokens: Int64
    var id: String { name }
}

private struct ModelChartItem: Identifiable {
    let agent: AgentKind
    let label: String
    let tokens: Int64
    var id: String { "\(agent.rawValue)-\(label)" }
}

private struct DayUsage: Identifiable {
    let date: Date
    let agents: [AgentKind]
    let input: Int64
    let output: Int64
    let cacheRead: Int64

    var id: Date { date }
    var total: Int64 { input + output }
}
