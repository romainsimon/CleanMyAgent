import SwiftUI

struct WorktreesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(
                title: "Worktrees",
                subtitle: "Git worktrees discovered under ~/dev. Dirty and locked state is checked locally."
            )

            if model.worktrees.isEmpty && !model.isScanning {
                ContentUnavailableView(
                    "No worktrees found",
                    systemImage: "arrow.triangle.branch",
                    description: Text("Agent Space found no Git worktrees in the current scan scope.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(model.worktrees) {
                    TableColumn("Repository") { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.repository).fontWeight(.medium)
                            Text(item.head)
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.agentSpaceSecondary)
                        }
                    }
                    .width(min: 120, ideal: 160)

                    TableColumn("Branch") { item in
                        Text(item.branch)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 130, ideal: 200)

                    TableColumn("Path") { item in
                        Text(item.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .font(.caption)
                            .foregroundStyle(Color.agentSpaceSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 220, ideal: 340)

                    TableColumn("State") { item in
                        HStack(spacing: 6) {
                            StatusDot(color: stateColor(item))
                            Text(stateLabel(item))
                        }
                    }
                    .width(90)

                    TableColumn("Size") { item in
                        Text(item.bytes > 0 ? ByteFormat.string(item.bytes) : "—")
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(90)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: false))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.agentSpaceSeparator, lineWidth: 1)
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "eye")
                Text("Inventory only. Agent Space cannot remove a worktree in this version.")
            }
            .font(.caption)
            .foregroundStyle(Color.agentSpaceSecondary)
        }
        .padding(28)
        .frame(maxWidth: 1200, maxHeight: .infinity, alignment: .topLeading)
    }

    private func stateLabel(_ item: WorktreeRecord) -> String {
        if item.isLocked { return "Locked" }
        if !item.statusKnown { return "Unknown" }
        return item.isDirty ? "Dirty" : "Clean"
    }

    private func stateColor(_ item: WorktreeRecord) -> Color {
        if item.isLocked { return .blue }
        if !item.statusKnown { return .secondary }
        return item.isDirty ? .orange : .green
    }
}
