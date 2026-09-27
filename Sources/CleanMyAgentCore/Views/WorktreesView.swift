import SwiftUI

struct WorktreesView: View {
    @ObservedObject var model: AppModel
    @State private var filter = WorktreeFilter.all
    @State private var selectedPaths: Set<String> = []
    @State private var showsConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    PageHeader(
                        title: "Worktrees",
                        subtitle: "Forgotten checkouts, with the evidence that tells you what should stay.",
                        illustration: "protected-folder"
                    )

                    auditSummary
                    cleanupNotice

                    HStack {
                        Picker("Filter", selection: $filter) {
                            ForEach(WorktreeFilter.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()

                        Spacer()

                        if model.isScanning {
                            ProgressView()
                                .controlSize(.small)
                            Text("Verifying Git and pull requests…")
                                .font(.caption)
                                .foregroundStyle(Color.cleanMyAgentSecondary)
                        }
                    }

                    if model.worktrees.isEmpty && !model.isScanning {
                        ContentUnavailableView(
                            "No worktrees found",
                            systemImage: "arrow.triangle.branch",
                            description: Text("CleanMyAgent found no linked Git worktrees under ~/dev.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        worktreeTable
                    }
                }
                .padding(28)
                .frame(maxWidth: 1200, alignment: .topLeading)
            }
            .minimalMacScrollbars()

            Divider()
                .overlay(Color.cleanMyAgentSeparator)

            actionBar
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.cleanMyAgentSurface)
        }
        .onChange(of: model.worktrees) { _, worktrees in
            let removablePaths = Set(worktrees.filter { $0.safety == .removable }.map(\.path))
            selectedPaths.formIntersection(removablePaths)
        }
        .sheet(isPresented: $showsConfirmation) {
            WorktreeCleanupConfirmationView(records: selectedRecords) {
                let paths = selectedPaths
                selectedPaths.removeAll()
                showsConfirmation = false
                Task { await model.removeWorktrees(paths: paths) }
            }
        }
    }

    private var auditSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), alignment: .leading)], alignment: .leading, spacing: 16) {
            summaryItem(value: model.worktrees.count.formatted(), label: "Audited", color: .primary)
            summaryItem(value: removableWorktrees.count.formatted(), label: "Ready for review", color: Color.cleanMyAgentGreen)
            summaryItem(value: ByteFormat.string(removableBytes), label: "Verified space", color: Color.cleanMyAgentGreen)
            summaryItem(value: protectedWorktrees.count.formatted(), label: "Protected", color: Color.cleanMyAgentAmber)
            }
            AgentLabel("Clean, inactive and verified merged. Rechecked before Git removes a checkout.", symbol: "checkmark.shield")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.cleanMyAgentSecondary)
        }
        .padding(18)
        .cleanMyAgentPanel(cornerRadius: 14)
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.cleanMyAgentSecondary)
        }
    }

    private var worktreeTable: some View {
        ViewThatFits(in: .horizontal) {
            wideWorktreeTable.frame(minWidth: 700)
            compactWorktreeList
        }
    }

    private var wideWorktreeTable: some View {
        VStack(spacing: 0) {
            worktreeTableHeader
            Divider().overlay(Color.cleanMyAgentSeparator)

            LazyVStack(spacing: 0) {
                ForEach(Array(filteredWorktrees.enumerated()), id: \.element.id) { index, item in
                    worktreeRow(item)
                    if index < filteredWorktrees.count - 1 {
                        Divider().overlay(Color.cleanMyAgentSeparator).padding(.leading, 54)
                    }
                }
            }
        }
        .background(Color.cleanMyAgentSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.cleanMyAgentSeparator, lineWidth: 1)
        }
    }

    private var worktreeTableHeader: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 28)
            Text("Repository").frame(width: 140, alignment: .leading)
            Text("Safety evidence").frame(width: 220, alignment: .leading)
            Text("Path").frame(maxWidth: .infinity, alignment: .leading)
            Text("Size").frame(width: 88, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.cleanMyAgentSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func worktreeRow(_ item: WorktreeRecord) -> some View {
        HStack(spacing: 12) {
            selectionControl(item)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.repository).fontWeight(.medium)
                Text(item.branch)
                    .font(.caption)
                    .foregroundStyle(Color.cleanMyAgentSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 140, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    AgentLabel(item.safety == .removable ? "Ready for review" : item.safety.label, symbol: item.safety == .removable ? "checkmark.shield" : "lock")
                        .foregroundStyle(item.safety == .removable ? Color.cleanMyAgentGreen : Color.cleanMyAgentAmber)
                        .fontWeight(.medium)
                }
                Text(item.safetyReason)
                    .font(.caption)
                    .foregroundStyle(Color.cleanMyAgentSecondary)
                    .lineLimit(1)
            }
            .frame(width: 220, alignment: .leading)
            .help(item.safetyReason)

            Text(shortPath(item.path))
                .font(.caption)
                .foregroundStyle(Color.cleanMyAgentSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(item.path)

            Text(item.bytes > 0 ? ByteFormat.string(item.bytes) : "—")
                .monospacedDigit()
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func selectionControl(_ item: WorktreeRecord) -> some View {
        Button {
            toggleSelection(item)
        } label: {
            Image(systemName: selectedPaths.contains(item.path) ? "checkmark.square.fill" : "square")
                .foregroundStyle(item.safety == .removable ? Color.cleanMyAgentBlue : Color.cleanMyAgentSecondary.opacity(0.45))
                .font(.system(size: 18))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(item.safety != .removable || model.worktreeCleanupState == .removing)
        .help(item.safety == .removable ? "Select for removal" : item.safetyReason)
        .accessibilityLabel("\(selectedPaths.contains(item.path) ? "Deselect" : "Select") worktree \(item.repository), \(item.branch)")
    }

    private var compactWorktreeList: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredWorktrees) { item in
                HStack(alignment: .top, spacing: 12) {
                    selectionControl(item)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(item.repository).font(.body.weight(.semibold))
                            Text(item.branch).font(.caption).foregroundStyle(Color.cleanMyAgentSecondary).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.bytes > 0 ? ByteFormat.string(item.bytes) : "—").monospacedDigit()
                        }
                        AgentLabel(item.safety == .removable ? "Ready for review" : item.safety.label, symbol: item.safety == .removable ? "checkmark.shield" : "lock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.safety == .removable ? Color.cleanMyAgentGreen : Color.cleanMyAgentAmber)
                        Text(item.safetyReason)
                            .font(.caption).foregroundStyle(Color.cleanMyAgentSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(shortPath(item.path))
                            .font(.caption).foregroundStyle(Color.cleanMyAgentSecondary)
                            .lineLimit(1).truncationMode(.middle).help(item.path)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cleanMyAgentPanel(cornerRadius: 14)
    }

    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                selectionLabel
                Spacer()
                selectionActions
            }
            VStack(alignment: .leading, spacing: 12) {
                selectionLabel
                HStack {
                    Spacer()
                    selectionActions
                }
            }
        }
    }

    private var selectionLabel: some View {
        AgentLabel(
                selectedRecords.isEmpty
                    ? "Select verified worktrees to remove"
                    : "\(selectedRecords.count) selected · \(ByteFormat.string(selectedBytes))", symbol: "checkmark.shield"
            )
            .font(.callout)
            .foregroundStyle(selectedRecords.isEmpty ? Color.cleanMyAgentSecondary : Color.cleanMyAgentGreen)

    }

    private var selectionActions: some View {
        HStack(spacing: 12) {
            Button(selectedPaths.count == removableWorktrees.count && !removableWorktrees.isEmpty ? "Clear selection" : "Select all safe") {
                if selectedPaths.count == removableWorktrees.count && !removableWorktrees.isEmpty {
                    selectedPaths.removeAll()
                } else {
                    selectedPaths = Set(removableWorktrees.map(\.path))
                }
            }
            .disabled(removableWorktrees.isEmpty || model.worktreeCleanupState == .removing)

            Button("Remove selected worktrees…", role: .destructive) {
                showsConfirmation = true
            }
            .disabled(selectedRecords.isEmpty || model.worktreeCleanupState == .removing)
            .buttonStyle(.borderedProminent)
            .tint(Color.cleanMyAgentRed)
        }
    }

    @ViewBuilder
    private var cleanupNotice: some View {
        switch model.worktreeCleanupState {
        case .idle:
            EmptyView()
        case .removing:
            AgentLabel("Rechecking every selected worktree before Git removes it…", symbol: "arrow.triangle.2.circlepath")
                .font(.callout)
                .foregroundStyle(Color.cleanMyAgentSecondary)
        case let .succeeded(removedCount, reclaimedBytes):
            notice(
                "Removed \(removedCount) worktrees and reclaimed about \(ByteFormat.string(reclaimedBytes)). Branches and remote pull requests were not deleted.",
                color: Color.cleanMyAgentGreen,
                symbol: "checkmark.circle.fill"
            )
        case let .partial(removedCount, reclaimedBytes, failures):
            notice(
                "Removed \(removedCount) worktrees (about \(ByteFormat.string(reclaimedBytes))). Protected \(failures.count) that changed or failed revalidation.",
                color: Color.cleanMyAgentAmber,
                symbol: "exclamationmark.triangle.fill"
            )
        case let .failed(message):
            notice(message, color: Color.cleanMyAgentAmber, symbol: "exclamationmark.triangle.fill")
        }
    }

    private func notice(_ message: String, color: Color, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AgentLabel(message, symbol: symbol)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Dismiss") { model.resetWorktreeCleanupMessage() }
        }
        .padding(13)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var filteredWorktrees: [WorktreeRecord] {
        switch filter {
        case .all: model.worktrees
        case .safe: removableWorktrees
        case .protected: protectedWorktrees
        }
    }

    private var removableWorktrees: [WorktreeRecord] {
        model.worktrees.filter { $0.safety == .removable }
    }

    private var protectedWorktrees: [WorktreeRecord] {
        model.worktrees.filter { $0.safety == .protected }
    }

    private var selectedRecords: [WorktreeRecord] {
        model.worktrees.filter { selectedPaths.contains($0.path) && $0.safety == .removable }
    }

    private var removableBytes: Int64 { removableWorktrees.reduce(0) { $0 + $1.bytes } }
    private var selectedBytes: Int64 { selectedRecords.reduce(0) { $0 + $1.bytes } }

    private func toggleSelection(_ item: WorktreeRecord) {
        guard item.safety == .removable else { return }
        if selectedPaths.contains(item.path) {
            selectedPaths.remove(item.path)
        } else {
            selectedPaths.insert(item.path)
        }
    }

    private func shortPath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

private enum WorktreeFilter: String, CaseIterable, Identifiable {
    case all
    case safe
    case protected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .safe: "Safe"
        case .protected: "Protected"
        }
    }
}

private struct WorktreeCleanupConfirmationView: View {
    let records: [WorktreeRecord]
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var acknowledged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                PhosphorIcon(symbol: "externaldrive.badge.checkmark")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.cleanMyAgentAmber)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Remove \(records.count) verified worktrees?")
                        .font(.title2.weight(.semibold))
                    Text("This reclaims about \(ByteFormat.string(records.reduce(0) { $0 + $1.bytes })). Git will recheck every target before removal.")
                        .foregroundStyle(Color.cleanMyAgentSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                AgentLabel("No uncommitted or untracked files", symbol: "checkmark.circle.fill")
                AgentLabel("No unpushed commits", symbol: "checkmark.circle.fill")
                AgentLabel("Merged into the default branch or through a merged PR", symbol: "checkmark.circle.fill")
                AgentLabel("Branches and pull requests remain intact", symbol: "checkmark.circle.fill")
            }
            .font(.callout)
            .foregroundStyle(Color.cleanMyAgentGreen)

            List(records) { record in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(record.repository) · \(record.branch)")
                        .fontWeight(.medium)
                    Text(record.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.cleanMyAgentSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 3)
            }
            .minimalMacScrollbars()
            .frame(minHeight: 120, maxHeight: 220)

            Toggle("I understand that Git removes these checkout folders directly; they do not go to the Trash.", isOn: $acknowledged)
                .toggleStyle(.checkbox)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Remove verified worktrees", role: .destructive) { confirm() }
                    .disabled(!acknowledged)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
                .frame(width: 620)
    }
}
