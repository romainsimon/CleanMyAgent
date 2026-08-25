import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "Settings",
                    subtitle: "Current scan scope, privacy contract, and safety mode."
                )

                settingsGroup("Scan scope") {
                    settingRow(symbol: "person.crop.circle", title: "Agent homes", value: "~/.codex · ~/.claude · ~/.grok")
                    Divider().overlay(Color.agentSpaceSeparator)
                    settingRow(symbol: "folder", title: "Project root", value: "~/dev")
                    Divider().overlay(Color.agentSpaceSeparator)
                    settingRow(symbol: "clock", title: "Refresh", value: "Manual · ⌘R")
                }

                settingsGroup("Privacy and safety") {
                    settingRow(symbol: "text.badge.xmark", title: "Conversation content", value: "Never indexed")
                    Divider().overlay(Color.agentSpaceSeparator)
                    settingRow(symbol: "network.slash", title: "Network", value: "No telemetry or uploads")
                    Divider().overlay(Color.agentSpaceSeparator)
                    settingRow(symbol: "lock.shield", title: "Cleaning mode", value: "Disabled in MVP")
                }

                Text("Future cleaning rules will require a preview and explicit confirmation. Sessions and active, dirty, unmerged, unknown, or open-PR worktrees will remain protected by default.")
                    .font(.callout)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .frame(maxWidth: 680, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title)
            VStack(spacing: 0) { content() }
                .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.agentSpaceSeparator, lineWidth: 1)
                }
        }
    }

    private func settingRow(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.agentSpaceSecondary)
        }
        .agentSpaceRow()
    }
}
