import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: AppSection? = .overview
    @Published private(set) var disk = DiskSnapshot.empty
    @Published private(set) var performance = PerformanceSnapshot.empty
    @Published private(set) var liveSpeed = LiveSpeedSnapshot.inactive
    @Published var usageRange: UsageRange = .thirtyDays
    @Published private(set) var usage = UsageSnapshot.empty()
    @Published private(set) var worktrees: [WorktreeRecord] = []
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
        let selectedUsageRange = usageRange
        async let usageTask = Task.detached(priority: .utility) { UsageScanner.scan(range: selectedUsageRange) }.value
        async let worktreeTask = Task.detached(priority: .utility) { WorktreeScanner.scan() }.value

        disk = await diskTask
        performance = await performanceTask
        usage = await usageTask
        worktrees = await worktreeTask
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

    private func monitorLiveSpeed() async {
        while !Task.isCancelled {
            liveSpeed = await liveSpeedMonitor.sample()
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
