import XCTest
@testable import CleanMyAgentCore

final class AgentMotionTests: XCTestCase {
    func testKeyboardAndReducedMotionAlwaysBypassSpatialAnimation() {
        XCTAssertTrue(AgentMotion.allowsAnimation(reduceMotion: false, keyboardInput: false))
        XCTAssertFalse(AgentMotion.allowsAnimation(reduceMotion: false, keyboardInput: true))
        XCTAssertFalse(AgentMotion.allowsAnimation(reduceMotion: true, keyboardInput: false))
        XCTAssertFalse(AgentMotion.allowsAnimation(reduceMotion: true, keyboardInput: true))
    }
}
