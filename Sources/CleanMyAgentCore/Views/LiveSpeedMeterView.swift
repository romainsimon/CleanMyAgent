import SwiftUI

struct LiveSpeedMeterView: View {
    let snapshot: LiveSpeedSnapshot
    var compact = false

    private let scaleMaximum = 120.0

    var body: some View {
        if compact {
            compactMeter
        } else {
            fullMeter
        }
    }

    private var compactMeter: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                PhosphorIcon(symbol: "gauge.with.dots.needle.50percent")
                    .font(.title3).foregroundStyle(meterColor)
                Text(snapshot.active ? "Codex is working" : "No active Codex turn")
                    .font(.callout.weight(.medium))
                Spacer(minLength: 0)
            }
            if snapshot.active {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formattedSpeed).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("observed tok/s").font(.caption).foregroundStyle(Color.cleanMyAgentSecondary)
                }
                MetricProgressTrack(fraction: meterFraction, color: meterColor)
                Text(snapshot.model ?? "Local Codex metadata")
                    .font(.caption).foregroundStyle(Color.cleanMyAgentSecondary)
            } else {
                Text("Live output speed appears here when Codex reports an active turn.")
                    .font(.callout).foregroundStyle(Color.cleanMyAgentSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .cleanMyAgentPanel()
    }

    private var fullMeter: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(meterColor.opacity(0.14))
                    PhosphorIcon(symbol: "gauge.with.dots.needle.50percent")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(meterColor)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(snapshot.observedTokensPerSecond, format: .number.precision(.fractionLength(1)))
                            .font(.system(size: 31, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("tok/s")
                            .font(.callout)
                            .foregroundStyle(Color.cleanMyAgentSecondary)
                    }
                    HStack(spacing: 7) {
                        StatusDot(color: meterColor)
                        Text(snapshot.active ? "Live Codex turn" : "Waiting for an active turn")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(snapshot.active ? meterColor : Color.cleanMyAgentSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(snapshot.model ?? "No model active")
                        .font(.headline)
                        .lineLimit(1)
                    Text(snapshot.active ? "Running for \(formatElapsed(snapshot.elapsedMs))" : "Monitoring local metadata")
                        .font(.caption)
                        .foregroundStyle(Color.cleanMyAgentSecondary)
                }
            }

            MetricProgressTrack(fraction: meterFraction, color: meterColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Live observed output tokens per second")
                .accessibilityValue("\(formattedSpeed) tokens per second on a \(scaleMaximum.formatted()) token per second scale")

            HStack(spacing: 22) {
                MetricLegendItem(color: meterColor, label: "Observed", value: "\(formattedSpeed) tok/s")
                MetricLegendItem(color: Color.cleanMyAgentTrack, label: "Scale", value: "\(scaleMaximum.formatted()) tok/s")
                Spacer()
                Text(snapshot.active
                     ? "\(snapshot.outputTokens.formatted()) output tokens reported"
                     : "Output tokens ÷ elapsed wall-clock time")
                    .font(.caption)
                    .foregroundStyle(Color.cleanMyAgentSecondary)
            }
        }
        .padding(20)
        .cleanMyAgentPanel(accent: snapshot.active ? Color.cleanMyAgentGreen : .cleanMyAgentViolet)
    }

    private var meterFraction: Double {
        min(1, max(0, snapshot.observedTokensPerSecond / scaleMaximum))
    }

    private var meterColor: Color {
        snapshot.active ? Color.cleanMyAgentGreen : Color.cleanMyAgentSecondary
    }

    private var formattedSpeed: String {
        snapshot.observedTokensPerSecond.formatted(.number.precision(.fractionLength(1)))
    }

    private func formatElapsed(_ milliseconds: Double) -> String {
        guard milliseconds > 0 else { return "—" }
        let seconds = Int(milliseconds / 1_000)
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }
}
