import AppKit
import SwiftUI

struct CleanView: View {
    @ObservedObject var model: AppModel
    @State private var pendingFamily: RegenerableCleanupFamily?
    @State private var showsArchiveConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "Clean safely",
                    subtitle: "Each rule names its allowlist, blocked states, and that space returns only after the Trash is emptied."
                )

                HStack(spacing: 10) {
                    Label("Revalidated at click", systemImage: "checkmark.shield")
                    Text("Sessions, images, and source stay protected")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.agentSpaceSecondary)

                VStack(alignment: .leading, spacing: 0) {
                    regenerableRow(
                        family: .worktreeDependencies,
                        state: model.dependencyCleanupState,
                        eligibleBytes: model.regenerableCleanup.eligibleBytes(in: .worktreeDependencies),
                        eligibleCount: model.regenerableCleanup.eligibleItems(in: .worktreeDependencies).count,
                        extra: model.regenerableCleanup.skippedActiveWorktrees > 0
                            ? "Skipped \(model.regenerableCleanup.skippedActiveWorktrees.formatted()) worktrees with a running process."
                            : "Unmerged worktrees stay. Only gitignored node_modules are selected."
                    )

                    Divider().overlay(Color.agentSpaceSeparator)

                    regenerableRow(
                        family: .developerCaches,
                        state: model.cacheCleanupState,
                        eligibleBytes: model.regenerableCleanup.eligibleBytes(in: .developerCaches),
                        eligibleCount: model.regenerableCleanup.eligibleItems(in: .developerCaches).count,
                        extra: cacheFootnote
                    )

                    Divider().overlay(Color.agentSpaceSeparator)

                    archiveRow
                }
                .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.agentSpaceSeparator, lineWidth: 1)
                }

                regenerableNotice(model.dependencyCleanupState, family: .worktreeDependencies)
                regenerableNotice(model.cacheCleanupState, family: .developerCaches)
                archiveNotice

                VStack(alignment: .leading, spacing: 8) {
                    Text("Before you clean")
                        .font(.headline)
                    Text("Items go to the macOS Trash and stay recoverable until you empty it. Disk space is reclaimed only after that. Active Codex sessions, generated images, repositories, and non-gitignored files are never selected.")
                        .font(.callout)
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 680, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .minimalMacScrollbars()
        .task { await model.refreshCleanupTarget() }
        .confirmationDialog(
            pendingFamily?.title ?? "",
            isPresented: Binding(
                get: { pendingFamily != nil },
                set: { if !$0 { pendingFamily = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let family = pendingFamily {
                Button(
                    "Move \(ByteFormat.string(model.regenerableCleanup.eligibleBytes(in: family))) to Trash",
                    role: .destructive
                ) {
                    let selected = family
                    pendingFamily = nil
                    Task { await model.moveRegenerableFamilyToTrash(selected) }
                }
            }
            Button("Cancel", role: .cancel) { pendingFamily = nil }
        } message: {
            if let family = pendingFamily {
                Text(confirmationMessage(for: family))
            }
        }
        .confirmationDialog(
            "Move archived Codex sessions to the Trash?",
            isPresented: $showsArchiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move \(ByteFormat.string(model.archivedSessions.bytes)) to Trash", role: .destructive) {
                Task { await model.moveArchivedSessionsToTrash() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(model.archivedSessions.fileCount.formatted()) archived tasks from Codex. Active sessions are not touched. Space is not reclaimed until you empty the Trash.")
        }
    }

    private var cacheFootnote: String {
        let blocked = model.regenerableCleanup.caches.filter { $0.blockedReason != nil }
        if blocked.contains(where: { $0.blockedReason?.contains("Codex") == true }) {
            return "Quit Codex to include its runtime caches. npm, Yarn, Playwright, and Puppeteer stay eligible."
        }
        return "Allowlist: npm _cacache, Yarn, Playwright, Puppeteer, Codex runtime caches."
    }

    private func regenerableRow(
        family: RegenerableCleanupFamily,
        state: RegenerableCleanupOperationState,
        eligibleBytes: Int64,
        eligibleCount: Int,
        extra: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: family.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.agentSpaceBlue)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 6) {
                    Text(family.title)
                        .font(.headline)
                    Text(family.summary)
                        .font(.callout)
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(extra)
                        .font(.caption)
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 20)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(ByteFormat.string(eligibleBytes))
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text(eligibleCount == 1 ? "1 folder" : "\(eligibleCount.formatted()) folders")
                        .font(.caption)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
            }

            HStack(spacing: 12) {
                regenerableStatus(state: state, eligibleCount: eligibleCount)
                Spacer()
                Button("Move to Trash…", role: .destructive) {
                    pendingFamily = family
                }
                .disabled(eligibleCount == 0 || state == .movingToTrash)
            }
        }
        .agentSpaceRow()
    }

    private var archiveRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "archivebox")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.agentSpaceBlue)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Archived Codex sessions")
                        .font(.headline)
                    Text(model.archivedSessions.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .textSelection(.enabled)
                    Text("Removes archived task history from Codex. Current sessions, repositories, and worktrees are not touched.")
                        .font(.callout)
                        .foregroundStyle(Color.agentSpaceSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 20)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(ByteFormat.string(model.archivedSessions.bytes))
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text("\(model.archivedSessions.fileCount.formatted()) files")
                        .font(.caption)
                        .foregroundStyle(Color.agentSpaceSecondary)
                }
            }

            HStack(spacing: 12) {
                archiveStatus
                Spacer()
                Button("Move to Trash…", role: .destructive) {
                    showsArchiveConfirmation = true
                }
                .disabled(!canCleanArchives)
            }
        }
        .agentSpaceRow()
    }

    private var canCleanArchives: Bool {
        model.archivedSessions.exists
            && model.archivedSessions.fileCount > 0
            && !model.codexIsRunning
            && model.cleanupState != .movingToTrash
    }

    @ViewBuilder
    private func regenerableStatus(state: RegenerableCleanupOperationState, eligibleCount: Int) -> some View {
        if state == .movingToTrash {
            ProgressView()
                .controlSize(.small)
            Text("Rechecking, then moving to Trash…")
                .font(.callout)
                .foregroundStyle(Color.agentSpaceSecondary)
        } else if eligibleCount == 0 {
            Label("Nothing eligible", systemImage: "checkmark.circle")
                .font(.callout)
                .foregroundStyle(.green)
        } else {
            Label("Allowlisted target ready", systemImage: "checkmark.shield")
                .font(.callout)
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var archiveStatus: some View {
        if model.cleanupState == .movingToTrash {
            ProgressView()
                .controlSize(.small)
            Text("Moving archives…")
                .font(.callout)
                .foregroundStyle(Color.agentSpaceSecondary)
        } else if model.codexIsRunning {
            Label("Quit Codex to enable archive cleanup", systemImage: "app.badge.checkmark")
                .font(.callout)
                .foregroundStyle(.orange)
        } else if model.archivedSessions.fileCount == 0 {
            Label("Nothing to clean", systemImage: "checkmark.circle")
                .font(.callout)
                .foregroundStyle(.green)
        } else {
            Label("Protected target ready", systemImage: "checkmark.shield")
                .font(.callout)
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private func regenerableNotice(_ state: RegenerableCleanupOperationState, family: RegenerableCleanupFamily) -> some View {
        switch state {
        case .idle, .movingToTrash:
            EmptyView()
        case let .succeeded(count, bytes):
            notice(
                "Moved \(count.formatted()) \(family.title.lowercased()) folders (about \(ByteFormat.string(bytes))) to the Trash.",
                color: .green,
                onDismiss: { model.resetRegenerableCleanupMessage(family) }
            )
        case let .partial(count, bytes, failures):
            notice(
                "Moved \(count.formatted()) folders (about \(ByteFormat.string(bytes))). Protected \(failures.count.formatted()) that changed on revalidation.",
                color: .orange,
                onDismiss: { model.resetRegenerableCleanupMessage(family) }
            )
        case let .failed(message):
            notice(message, color: .orange, onDismiss: { model.resetRegenerableCleanupMessage(family) })
        }
    }

    @ViewBuilder
    private var archiveNotice: some View {
        switch model.cleanupState {
        case .succeeded:
            HStack(spacing: 12) {
                Label("Archives moved to the Trash. Empty it when you are ready to reclaim the space.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("Open Trash") { openTrash() }
            }
            .padding(14)
            .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case let .failed(message):
            notice(message, color: .orange, onDismiss: { model.resetCleanupMessage() })
        case .idle, .movingToTrash:
            EmptyView()
        }
    }

    private func notice(_ message: String, color: Color, onDismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Label(message, systemImage: color == .green ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Dismiss", action: onDismiss)
        }
        .padding(14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func confirmationMessage(for family: RegenerableCleanupFamily) -> String {
        let count = model.regenerableCleanup.eligibleItems(in: family).count
        switch family {
        case .worktreeDependencies:
            return "This moves \(count.formatted()) gitignored node_modules folders from inactive extra worktrees to the Trash. Git history and the worktrees themselves stay. Space is not reclaimed until you empty the Trash."
        case .developerCaches:
            return "This moves \(count.formatted()) allowlisted cache folders to the Trash. Codex sessions and generated images are not selected. Space is not reclaimed until you empty the Trash."
        }
    }

    private func openTrash() {
        if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(trashURL)
        }
    }
}
