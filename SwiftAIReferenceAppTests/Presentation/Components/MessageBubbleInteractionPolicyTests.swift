import XCTest
@testable import SwiftAIReferenceApp

final class MessageBubbleInteractionPolicyTests: XCTestCase {
    func testUserRoleUsesWholeBubbleCopyOnly() {
        let policy = MessageBubbleInteractionPolicy.forRole(.user)

        XCTAssertFalse(policy.enablesTextSelection)
        XCTAssertTrue(policy.showsCopyContextMenu)
    }

    func testAssistantRoleUsesSelectionOnly() {
        let policy = MessageBubbleInteractionPolicy.forRole(.assistant)

        XCTAssertTrue(policy.enablesTextSelection)
        XCTAssertFalse(policy.showsCopyContextMenu)
    }

    func testSystemRoleHasNoCopyAffordance() {
        let policy = MessageBubbleInteractionPolicy.forRole(.system)

        XCTAssertFalse(policy.enablesTextSelection)
        XCTAssertFalse(policy.showsCopyContextMenu)
    }
}
