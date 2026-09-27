import Foundation
import Testing
@testable import AgentSpace

struct AppModelTests {
    @MainActor @Test func screenshotModeKeepsFixtureIsolationAndCleanupGuards() async throws {
        let model = AppModel(screenshotMode: true, usageScanner: { range in
            Issue.record("Screenshot mode must not run the live usage scanner")
            return .empty(range: range)
        })
        try #require(model.isDemo)
        #expect(!model.isScanning)
        #expect(model.disk.totalBytes == 512 * 1_073_741_824)
        let originalPaths = model.worktrees.map(\.path)
        await model.refresh()
        await model.refreshCleanupTarget()
        model.usageRange = .sevenDays
        await model.refreshUsage()
        await model.moveRegenerableFamilyToTrash(.worktreeDependencies)
        await model.moveRegenerableFamilyToTrash(.developerCaches)
        await model.moveArchivedSessionsToTrash()
        await model.removeWorktrees(paths: Set(originalPaths))
        #expect(model.worktrees.map(\.path) == originalPaths)
        #expect(model.usage.range == .sevenDays)
        #expect(!model.isScanning && !model.isUsageScanning)
        #expect(model.cleanupState == .idle)
        #expect(model.dependencyCleanupState == .idle)
        #expect(model.cacheCleanupState == .idle)
        #expect(model.worktreeCleanupState == .idle)
    }

    @MainActor @Test func publishesTheLatestRangeRequestedDuringAScan() async {
        let gate = UsageScanGate()
        let model = AppModel(scanOnLaunch: false, usageScanner: { range in
            gate.scan()
            return .empty(range: range)
        })
        defer { gate.proceed.signal() }
        let first = Task { await model.refreshUsage() }
        await gate.waitForStart()
        #expect(model.isUsageScanning)
        model.usageRange = .sevenDays
        await model.refreshUsage()
        gate.proceed.signal()
        await first.value
        #expect(model.usage.range == .sevenDays)
        #expect(!model.isUsageScanning)
    }
}

private final class UsageScanGate: @unchecked Sendable {
    let proceed = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var first = true
    private var started = false
    private var startObserver: CheckedContinuation<Void, Never>?
    func waitForStart() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if started {
                lock.unlock()
                continuation.resume()
            } else {
                startObserver = continuation
                lock.unlock()
            }
        }
    }
    func scan() {
        lock.lock()
        let mustWait = first
        first = false
        let observer = mustWait ? startObserver : nil
        if mustWait { started = true; startObserver = nil }
        lock.unlock()
        if mustWait { observer?.resume(); proceed.wait() }
    }
}
