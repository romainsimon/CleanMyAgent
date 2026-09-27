import XCTest
@testable import AgentSpace

final class PreviewParityTests: XCTestCase {
    func testSevenDayPublicFixtureAgreesWithTheWebsiteAndCountsTokensOnce() {
        let usage = DemoData.usage(range: .sevenDays, annotateDemo: false)
        XCTAssertEqual(usage.totalTokens, 566_290)
        XCTAssertEqual(usage.cacheReadTokens, 168_000)
        XCTAssertEqual(usage.totalTokens, usage.inputTokens + usage.outputTokens)
        XCTAssertEqual(usage.buckets.reduce(0) { $0 + $1.uncachedInputTokens + $1.cacheReadTokens + $1.cacheWriteTokens + $1.visibleOutputTokens + $1.reasoningTokens }, usage.totalTokens)
        let days = Dictionary(grouping: usage.buckets, by: \.date)
        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days.values.allSatisfy { Set($0.map(\.agent)) == [.codex, .claude] })
    }
}
