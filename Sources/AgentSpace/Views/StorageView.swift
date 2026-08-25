import SwiftUI

struct StorageView: View {
    @ObservedObject var model: AppModel

    private var categories: [StorageCategory] {
        (model.disk.agents.flatMap(\.categories) + model.disk.sharedCategories)
            .sorted { $0.bytes > $1.bytes }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeader(
                title: "Storage",
                subtitle: "Measured local categories, largest first. Paths are never sent over the network."
            )

            VStack(spacing: 0) {
                HStack {
                    Text("Category").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Source").frame(width: 130, alignment: .leading)
                    Text("Size").frame(width: 110, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.agentSpaceSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider().overlay(Color.agentSpaceSeparator)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            StorageCategoryRow(category: category, showAgent: true)
                            if index < categories.count - 1 {
                                Divider().overlay(Color.agentSpaceSeparator).padding(.leading, 42)
                            }
                        }
                    }
                }
            }
            .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.agentSpaceSeparator, lineWidth: 1)
            }

            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                Text("Audit-only build. No cleanup actions are enabled.")
            }
            .font(.caption)
            .foregroundStyle(Color.agentSpaceSecondary)
        }
        .padding(28)
        .frame(maxWidth: 1120, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct StorageCategoryRow: View {
    let category: StorageCategory
    let showAgent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(category.agent.map(Color.agentAccent) ?? .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.body)
                Text(category.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.caption2)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showAgent {
                Text(category.agent?.rawValue ?? "Shared")
                    .font(.caption)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .frame(width: 130, alignment: .leading)
            }

            Text(ByteFormat.string(category.bytes))
                .font(.body.weight(.medium))
                .monospacedDigit()
                .frame(width: 110, alignment: .trailing)
        }
        .agentSpaceRow()
    }

    private var symbol: String {
        switch category.kind {
        case .sessions: "text.bubble"
        case .cache: "shippingbox"
        case .plugins: "puzzlepiece.extension"
        case .logs: "doc.text"
        case .worktrees: "arrow.triangle.branch"
        case .other: "folder"
        }
    }
}
