import SwiftUI

enum AgentAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let preferenceKey = "CleanMyAgent.appearance"
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .system: "desktop"
        case .light: "sun"
        case .dark: "moon"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct AppearanceSwitcher: View {
    @AppStorage(AgentAppearance.preferenceKey) private var appearance = AgentAppearance.system

    var body: some View {
        Picker("Appearance", selection: $appearance) {
            ForEach(AgentAppearance.allCases) { option in
                Label {
                    Text(option.title)
                } icon: {
                    PhosphorIcon(option.icon, size: 16)
                }
                    .labelStyle(.iconOnly)
                    .tag(option)
                    .accessibilityLabel(option.title)
                    .help("\(option.title) appearance")
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("App appearance")
        .accessibilityValue(appearance.title)
    }
}

struct AppearanceSettings: View {
    @AppStorage(AgentAppearance.preferenceKey) private var appearance = AgentAppearance.system
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Appearance")
            HStack(spacing: 12) {
                ForEach(AgentAppearance.allCases) { option in
                    Button { appearance = option } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            appearancePreview(option)
                            HStack(spacing: 7) {
                                PhosphorIcon(option.icon, size: 18)
                                Text(option.title).font(.callout.weight(.medium))
                                Spacer(minLength: 0)
                                PhosphorIcon(appearance == option ? "check-circle" : "circle", size: 18)
                                    .foregroundStyle(appearance == option ? Color.cleanMyAgentAccent : Color.cleanMyAgentSecondary)
                            }
                        }
                        .padding(12)
                        .foregroundStyle(Color.cleanMyAgentText)
                        .background(appearance == option ? Color.cleanMyAgentSelection : Color.cleanMyAgentSurface,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(appearance == option ? Color.cleanMyAgentAccent : Color.cleanMyAgentSeparator,
                                        lineWidth: appearance == option ? 1.5 : 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.title) appearance")
                    .accessibilityAddTraits(appearance == option ? .isSelected : [])
                }
            }
            Text("System follows your Mac. Your choice is saved for the next launch.")
                .font(.callout).foregroundStyle(Color.cleanMyAgentSecondary)
        }
    }

    private func appearancePreview(_ option: AgentAppearance) -> some View {
        let dark = option == .dark || (option == .system && colorScheme == .dark)
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                PhosphorIcon("squares-four", size: 14)
                    .foregroundStyle(Color(AgentPalette.hex(.accent, dark: dark)))
                RoundedRectangle(cornerRadius: 2).fill(Color(AgentPalette.hex(.secondary, dark: dark))).frame(width: 22, height: 3)
                RoundedRectangle(cornerRadius: 2).fill(Color(AgentPalette.hex(.secondary, dark: dark)).opacity(0.4)).frame(width: 18, height: 3)
                Spacer(minLength: 0)
            }
            .padding(10).frame(width: 48)
            .background(Color(AgentPalette.hex(.sidebar, dark: dark)))
            VStack(alignment: .leading, spacing: 9) {
                RoundedRectangle(cornerRadius: 3).fill(Color(AgentPalette.hex(.text, dark: dark))).frame(width: 48, height: 5)
                HStack(spacing: 5) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(AgentPalette.hex(index == 0 ? .selection : .surface, dark: dark)))
                            .frame(height: 22)
                    }
                }
                RoundedRectangle(cornerRadius: 4).fill(Color(AgentPalette.hex(.surface, dark: dark))).frame(height: 18)
            }
            .padding(10).frame(maxWidth: .infinity)
        }
        .frame(height: 85)
        .background(Color(AgentPalette.hex(.background, dark: dark)))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }
}
