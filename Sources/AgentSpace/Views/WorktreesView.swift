import SwiftUI

struct WorktreesView: View {
    @ObservedObject var model: AppModel
    @State private var filter = WorktreeFilter.all
    @State private var selectedPaths: Set<String> = []
    @State private var showsConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Worktrees",
                    subtitle: "Remove only clean worktrees whose code is verified as merged and remote-backed."
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
                            .foregroundStyle(Color.agentSpaceSecondary)
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

                actionBar
            }
            .padding(28)
            .frame(maxWidth: 1200, alignment: .topLeading)
        }
        .minimalMacScrollbars()
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
        HStack(spacing: 0) {
            summaryItem(value: model.worktrees.count.formatted(), label: "Audited", color: .primary)
            Divider().frame(height: 32).padding(.horizontal, 18)
            summaryItem(value: removableWorktrees.count.formatted(), label: "Safe to remove", color: .green)
            Divider().frame(height: 32).padding(.horizontal, 18)
            summaryItem(value: ByteFormat.string(removableBytes), label: "Verified space", color: .green)
            Divider().frame(height: 32).padding(.horizontal, 18)
            summaryItem(value: protectedWorktrees.count.formatted(), label: "Protected", color: .orange)
            Spacer()
            Label("Rechecked before removal", systemImage: "checkmark.shield")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.agentSpaceSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.agentSpaceSeparator, lineWidth: 1)
        }
    }

    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.agentSpaceSecondary)
        }
    }

    private var worktreeTable: some View {
        VStack(spacing: 0) {
            worktreeTableHeader
            Divider().overlay(Color.agentSpaceSeparator)

            LazyVStack(spacing: 0) {
                ForEach(Array(filteredWorktrees.enumerated()), id: \.element.id) { index, item in
                    worktreeRow(item)
                    if index < filteredWorktrees.count - 1 {
                        Divider().overlay(Color.agentSpaceSeparator).padding(.leading, 54)
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

    private var worktreeTableHeader: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 28)
            Text("Repository").frame(width: 140, alignment: .leading)
            Text("Safety evidence").frame(width: 220, alignment: .leading)
            Text("Path").frame(maxWidth: .infinity, alignment: .leading)
            Text("Size").frame(width: 88, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.agentSpaceSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func worktreeRow(_ item: WorktreeRecord) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleSelection(item)
            } label: {
                Image(systemName: selectedPaths.contains(item.path) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.safety == .removable ? Color.accentColor : Color.secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
            .frame(width: 28)
            .disabled(item.safety != .removable || model.worktreeCleanupState == .removing)
            .help(item.safety == .removable ? "Select for removal" : item.safetyReason)
            .accessibilityLabel(selectedPaths.contains(item.path) ? "Deselect worktree" : "Select worktree")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.repository).fontWeight(.medium)
                Text(item.branch)
                    .font(.caption)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 140, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    StatusDot(color: item.safety == .removable ? .green : .orange)
                    Text(item.safety.label).fontWeight(.medium)
                }
                Text(item.safetyReason)
                    .font(.caption)
                    .foregroundStyle(Color.agentSpaceSecondary)
                    .lineLimit(1)
            }
            .frame(width: 220, alignment: .leading)
            .help(item.safetyReason)

            Text(shortPath(item.path))
                .font(.caption)
                .foregroundStyle(Color.agentSpaceSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(item.path)

            Text(item.bytes > 0 ? ByteFormat.string(item.bytes) : "—")
                .monospacedDigit()
                .frame(width: 88, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Label(
                selectedRecords.isEmpty
                    ? "Select verified worktrees to remove"
                    : "\(selectedRecords.count) selected · \(ByteFormat.string(selectedBytes))",
                systemImage: "checkmark.shield"
            )
            .font(.callout)
            .foregroundStyle(selectedRecords.isEmpty ? Color.agentSpaceSecondary : .green)

            Spacer()

            Button(selectedPaths.count == removableWorktrees.count && !removableWorktrees.isEmpty ? "Clear selection" : "Select all safe") {
                if selectedPaths.count == removableWorktrees.count && !removableWorktrees.isEmpty {
                    selectedPaths.removeAll()
                } else {
                    selectedPaths = Set(removableWorktrees.map(\.path))
                }
            }
            .disabled(removableWorktrees.isEmpty || model.worktreeCleanupState == .removing)

            Button("Remove selected…", role: .destructive) {
                showsConfirmation = true
            }
            .disabled(selectedRecords.isEmpty || model.worktreeCleanupState == .removing)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var cleanupNotice: some View {
        switch model.worktreeCleanupState {
        case .idle:
            EmptyView()
        case .removing:
            Label("Rechecking every selected worktree before Git removes it…", systemImage: "arrow.triangle.2.circlepath")
                .font(.callout)
                .foregroundStyle(Color.agentSpaceSecondary)
        case let .succeeded(removedCount, reclaimedBytes):
            notice(
                "Removed \(removedCount) worktrees and reclaimed about \(ByteFormat.string(reclaimedBytes)). Branches and remote pull requests were not deleted.",
                color: .green,
                symbol: "checkmark.circle.fill"
            )
        case let .partial(removedCount, reclaimedBytes, failures):
            notice(
                "Removed \(removedCount) worktrees (about \(ByteFormat.string(reclaimedBytes))). Protected \(failures.count) that changed or failed revalidation.",
                color: .orange,
                symbol: "exclamationmark.triangle.fill"
            )
        case let .failed(message):
            notice(message, color: .orange, symbol: "exclamationmark.triangle.fill")
        }
    }

    private func notice(_ message: String, color: Color, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Label(message, systemImage: symbol)
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
                Image(systemName: "externaldrive.badge.checkmark")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Remove \(records.count) verified worktrees?")
                        .font(.title2.weight(.semibold))
                    Text("This reclaims about \(ByteFormat.string(records.reduce(0) { $0 + $1.bytes })). Git will recheck every target before removal.")
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("No uncommitted or untracked files", systemImage: "checkmark.circle.fill")
                Label("No unpushed commits", systemImage: "checkmark.circle.fill")
                Label("Merged into the default branch or through a merged PR", systemImage: "checkmark.circle.fill")
                Label("Branches and pull requests remain intact", systemImage: "checkmark.circle.fill")
            }
            .font(.callout)
            .foregroundStyle(.green)

            List(records) { record in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(record.repository) · \(record.branch)")
                        .fontWeight(.medium)
                    Text(record.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.agentSpaceSecondary)
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
