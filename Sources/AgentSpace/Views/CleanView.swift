import AppKit
import SwiftUI

struct CleanView: View {
    @ObservedObject var model: AppModel
    @State private var showsConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "Clean safely",
                    subtitle: "Review one protected target at a time. Nothing is deleted permanently."
                )

                HStack(spacing: 10) {
                    Label("Codex archives only", systemImage: "checkmark.shield")
                    Text("Active sessions stay untouched")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.agentSpaceSecondary)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.blue)
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
                    .agentSpaceRow()

                    Divider().overlay(Color.agentSpaceSeparator)

                    HStack(spacing: 12) {
                        statusLabel
                        Spacer()
                        Button("Move to Trash…", role: .destructive) {
                            showsConfirmation = true
                        }
                        .disabled(!canClean)
                    }
                    .agentSpaceRow()
                }
                .background(Color.agentSpaceSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.agentSpaceSeparator, lineWidth: 1)
                }

                notice

                VStack(alignment: .leading, spacing: 8) {
                    Text("Before you clean")
                        .font(.headline)
                    Text("Quit Codex first. The archived tasks remain recoverable from the Trash until you empty it. Disk space is reclaimed only after the Trash is emptied.")
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
            "Move archived Codex sessions to the Trash?",
            isPresented: $showsConfirmation,
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

    private var canClean: Bool {
        model.archivedSessions.exists
            && model.archivedSessions.fileCount > 0
            && !model.codexIsRunning
            && model.cleanupState != .movingToTrash
    }

    @ViewBuilder
    private var statusLabel: some View {
        if model.cleanupState == .movingToTrash {
            ProgressView()
                .controlSize(.small)
            Text("Moving archives…")
                .font(.callout)
                .foregroundStyle(Color.agentSpaceSecondary)
        } else if model.codexIsRunning {
            Label("Quit Codex to enable cleanup", systemImage: "app.badge.checkmark")
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
    private var notice: some View {
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
            HStack(alignment: .top, spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Button("Dismiss") { model.resetCleanupMessage() }
            }
            .padding(14)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .idle, .movingToTrash:
            EmptyView()
        }
    }

    private func openTrash() {
        if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(trashURL)
        }
    }
}
