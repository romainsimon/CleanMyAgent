import SwiftUI

struct LiveSpeedMeterView: View {
    let snapshot: LiveSpeedSnapshot

    private let scaleMaximum = 120.0

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    StatusDot(color: snapshot.active ? .green : .secondary)
                    Text(snapshot.active ? "Live Codex turn" : "Live speedometer")
                        .font(.headline)
                }
                Spacer()
                Text(snapshot.observedTokensPerSecond, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("tok/s")
                    .font(.callout)
                    .foregroundStyle(Color.agentSpaceSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(snapshot.active ? Color.green : Color.white.opacity(0.16))
                        .frame(width: max(4, proxy.size.width * meterFraction))
                }
            }
            .frame(height: 7)
            .accessibilityLabel("Live observed output tokens per second")
            .accessibilityValue("\(snapshot.observedTokensPerSecond.formatted(.number.precision(.fractionLength(1)))) tokens per second")

            HStack(spacing: 18) {
                detail(snapshot.model ?? "Waiting for an active turn", label: "Model")
                detail(snapshot.outputTokens.formatted(), label: "Output tokens")
                detail(formatElapsed(snapshot.elapsedMs), label: "Elapsed")
                Spacer()
                Text("Output tokens reported so far ÷ elapsed wall-clock time")
                    .font(.caption2)
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

    private var meterFraction: Double {
        min(1, max(0, snapshot.observedTokensPerSecond / scaleMaximum))
    }

    private func detail(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.agentSpaceSecondary)
        }
    }

    private func formatElapsed(_ milliseconds: Double) -> String {
        guard milliseconds > 0 else { return "—" }
        let seconds = Int(milliseconds / 1_000)
        return seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s" : "\(seconds)s"
    }
}
