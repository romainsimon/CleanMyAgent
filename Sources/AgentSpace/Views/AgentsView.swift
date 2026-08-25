import SwiftUI

struct AgentsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "Agents",
                    subtitle: "Installed tools and the local data categories observed for each one."
                )

                ForEach(model.disk.agents) { storage in
                    agentSection(storage)
                }
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .minimalMacScrollbars()
    }

    private func agentSection(_ storage: AgentStorage) -> some View {
        let runtime = model.runtime(for: storage.agent)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                AgentBadge(agent: storage.agent, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(storage.agent.rawValue)
                            .font(.headline)
                        if let version = storage.version {
                            Text(version)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.agentSpaceSecondary)
                        }
                    }
                    Text(storage.isInstalled ? storage.rootPath.replacingOccurrences(of: NSHomeDirectory(), with: "~") : "Not installed")
                        .font(.caption)
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .lineLimit(1)
                    Text(storage.agent.capabilitySummary)
                        .font(.caption2)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(ByteFormat.string(storage.totalBytes))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text(runtime.processCount > 0
                         ? "\(ByteFormat.string(runtime.residentBytes)) RAM · \(runtime.processCount) processes"
                         : "No active process")
                        .font(.caption2)
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .monospacedDigit()
                }
            }
            .padding(14)

            if storage.categories.isEmpty {
                Divider().overlay(Color.agentSpaceSeparator)
                Text(storage.isInstalled ? "No known categories were found." : "Install the agent to enable this adapter.")
                    .font(.callout)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else {
                Divider().overlay(Color.agentSpaceSeparator)
                ForEach(Array(storage.categories.enumerated()), id: \.element.id) { index, category in
                    StorageCategoryRow(category: category, showAgent: false)
                    if index < storage.categories.count - 1 {
                        Divider().overlay(Color.agentSpaceSeparator).padding(.leading, 14)
                    }
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
