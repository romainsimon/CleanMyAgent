import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: AppSection? = .overview
    @Published private(set) var disk = DiskSnapshot.empty
    @Published private(set) var performance = PerformanceSnapshot.empty
    @Published private(set) var worktrees: [WorktreeRecord] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastError: String?

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        lastError = nil

        async let diskTask = Task.detached(priority: .utility) { StorageScanner.scan() }.value
        async let performanceTask = Task.detached(priority: .utility) { PerformanceScanner.scan() }.value
        async let worktreeTask = Task.detached(priority: .utility) { WorktreeScanner.scan() }.value

        disk = await diskTask
        performance = await performanceTask
        worktrees = await worktreeTask
        isScanning = false
    }

    var totalAgentBytes: Int64 {
        disk.agents.reduce(0) { $0 + $1.totalBytes } + disk.sharedCategories.reduce(0) { $0 + $1.bytes }
    }
}
