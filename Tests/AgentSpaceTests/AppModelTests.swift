import Foundation
import Testing
@testable import AgentSpace

struct AppModelTests {
    @MainActor @Test func publishesTheLatestRangeRequestedDuringAScan() async {
        let gate = UsageScanGate()
        let model = AppModel(scanOnLaunch: false, usageScanner: { range in
            gate.scan()
            return .empty(range: range)
        })
        let first = Task { await model.refreshUsage() }
        #expect(await Task.detached { gate.waitForStart() }.value)
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
    let started = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var first = true
    func waitForStart() -> Bool { started.wait(timeout: .now() + 5) == .success }
    func scan() {
        lock.lock()
        let mustWait = first
        first = false
        lock.unlock()
        if mustWait { started.signal(); _ = proceed.wait(timeout: .now() + 5) }
    }
}
