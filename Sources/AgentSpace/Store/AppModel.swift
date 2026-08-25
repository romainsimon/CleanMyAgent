import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: AppSection? = .overview
    @Published private(set) var disk = DiskSnapshot.empty
    @Published private(set) var performance = PerformanceSnapshot.empty
    @Published private(set) var liveSpeed = LiveSpeedSnapshot.inactive
    @Published private(set) var runtime = RuntimeSnapshot.empty
    @Published var usageRange: UsageRange = .thirtyDays
    @Published private(set) var usage = UsageSnapshot.empty()
    @Published private(set) var worktrees: [WorktreeRecord] = []
    @Published private(set) var archivedSessions = CleanupTargetSnapshot.empty
    @Published private(set) var cleanupState = CleanupOperationState.idle
    @Published private(set) var worktreeCleanupState = WorktreeCleanupOperationState.idle
    @Published private(set) var codexIsRunning = false
    @Published private(set) var isScanning = false
    @Published private(set) var isUsageScanning = false
    @Published private(set) var lastError: String?
    private let liveSpeedMonitor = LiveSpeedMonitor()

    init() {
        Task { await refresh() }
        Task { await monitorLiveSpeed() }
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        lastError = nil

        async let diskTask = Task.detached(priority: .utility) { StorageScanner.scan() }.value
        async let performanceTask = Task.detached(priority: .utility) { PerformanceScanner.scan() }.value
        async let runtimeTask = Task.detached(priority: .utility) { ProcessScanner.scan() }.value
        let selectedUsageRange = usageRange
        async let usageTask = Task.detached(priority: .utility) { UsageScanner.scan(range: selectedUsageRange) }.value
        async let worktreeTask = Task.detached(priority: .utility) { WorktreeScanner.scan() }.value
        async let archiveTask = Task.detached(priority: .utility) { ArchiveCleanupService.scan() }.value

        disk = await diskTask
        performance = await performanceTask
        runtime = await runtimeTask
        usage = await usageTask
        worktrees = await worktreeTask
        archivedSessions = await archiveTask
        codexIsRunning = Self.detectCodexRunning()
        isScanning = false
    }

    func refreshUsage() async {
        guard !isUsageScanning else { return }
        isUsageScanning = true
        let selectedRange = usageRange
        usage = await Task.detached(priority: .utility) {
            UsageScanner.scan(range: selectedRange)
        }.value
        isUsageScanning = false
    }

    var totalAgentBytes: Int64 {
        disk.agents.reduce(0) { $0 + $1.totalBytes } + disk.sharedCategories.reduce(0) { $0 + $1.bytes }
    }

    func runtime(for agent: AgentKind) -> AgentRuntime {
        runtime.agents.first(where: { $0.agent == agent })
            ?? AgentRuntime(agent: agent, residentBytes: 0, processCount: 0)
    }

    func refreshCleanupTarget() async {
        archivedSessions = await Task.detached(priority: .utility) {
            ArchiveCleanupService.scan()
        }.value
        codexIsRunning = Self.detectCodexRunning()
    }

    func moveArchivedSessionsToTrash() async {
        guard cleanupState != .movingToTrash else { return }
        codexIsRunning = Self.detectCodexRunning()
        guard !codexIsRunning else {
            cleanupState = .failed(message: ArchiveCleanupError.codexIsRunning.localizedDescription)
            return
        }

        cleanupState = .movingToTrash
        do {
            let trashedURL = try await Task.detached(priority: .userInitiated) {
                try ArchiveCleanupService.moveToTrash()
            }.value
            cleanupState = .succeeded(trashedPath: trashedURL?.path ?? "Trash")
            await refresh()
        } catch {
            cleanupState = .failed(message: error.localizedDescription)
            await refreshCleanupTarget()
        }
    }

    func resetCleanupMessage() {
        cleanupState = .idle
    }

    func removeWorktrees(paths: Set<String>) async {
        guard worktreeCleanupState != .removing else { return }
        let selectedRecords = worktrees.filter { paths.contains($0.path) && $0.safety == .removable }
        guard !selectedRecords.isEmpty else {
            worktreeCleanupState = .failed(message: WorktreeCleanupError.nothingSelected.localizedDescription)
            return
        }

        worktreeCleanupState = .removing
        let result = await Task.detached(priority: .userInitiated) {
            WorktreeCleanupService.remove(selectedRecords)
        }.value
        await refresh()

        if result.failures.isEmpty {
            worktreeCleanupState = .succeeded(
                removedCount: result.removedPaths.count,
                reclaimedBytes: result.reclaimedBytes
            )
        } else if !result.removedPaths.isEmpty {
            worktreeCleanupState = .partial(
                removedCount: result.removedPaths.count,
                reclaimedBytes: result.reclaimedBytes,
                failures: result.failures
            )
        } else {
            worktreeCleanupState = .failed(
                message: result.failures.map(\.message).joined(separator: "\n")
            )
        }
    }

    func resetWorktreeCleanupMessage() {
        worktreeCleanupState = .idle
    }

    private static func detectCodexRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            application.bundleIdentifier == "com.openai.codex"
        }
    }

    private func monitorLiveSpeed() async {
        while !Task.isCancelled {
            liveSpeed = await liveSpeedMonitor.sample()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
