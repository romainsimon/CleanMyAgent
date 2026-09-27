import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var projectRoot = ScanConfiguration.developmentRoot
    @State private var scopeError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "Settings",
                    subtitle: "Current scan scope, privacy contract, and safety mode.",
                    illustration: "bento-mac"
                )

                AppearanceSettings()

                settingsGroup("Scan scope") {
                    settingRow(symbol: "person.crop.circle", title: "Agent homes", value: "Codex · Claude · Grok · Cursor · Hermes · OpenCode · Ori · Kilo")
                    Divider().overlay(Color.agentSpaceSeparator)
                    HStack(spacing: 12) {
                        Text("Development folder")
                        TextField("Folder path", text: $projectRoot)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Development folder path")
                        Button("Apply") {
                            if ScanConfiguration.saveDevelopmentRoot(projectRoot) {
                                scopeError = nil
                                Task { await model.refresh() }
                            } else { scopeError = "Enter an existing folder, for example ~/dev." }
                        }
                        .disabled(model.isScanning || model.isDemo)
                    }.agentSpaceRow()
                    if let scopeError { Text(scopeError).foregroundStyle(Color.agentSpaceRed).padding(.horizontal, 16) }
                    Divider().overlay(Color.agentSpaceSeparator)
                    settingRow(symbol: "clock", title: "Refresh", value: "Manual · ⌘R")
                }

                settingsGroup("Privacy and safety") {
                    settingRow(symbol: "text.badge.xmark", title: "Conversation content", value: "Never indexed")
                    Divider().overlay(Color.agentSpaceSeparator)
                    settingRow(symbol: "network", title: "Network", value: "GitHub PR verification only")
                    Divider().overlay(Color.agentSpaceSeparator)
                    settingRow(symbol: "lock.shield", title: "Cleaning mode", value: "Reviewed targets only")
                }

                Text("Cleaning requires a preview and explicit confirmation. GitHub PR metadata is read through the local gh login and is never uploaded by CleanMyAgent. Active sessions and active, dirty, unmerged, unknown, or open-PR worktrees remain protected. Archived Codex sessions can only be moved to the Trash while Codex is closed.")
                    .font(.callout)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .frame(maxWidth: 680, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .minimalMacScrollbars()
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
            PhosphorIcon(symbol: symbol)
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
