import SwiftUI
import XCTest
@testable import SwiftAIReferenceApp

@MainActor
final class ConversationsListToolbarActionsViewTests: XCTestCase {
    func testSettingsButtonInvokesActionWhenTapped() {
        var didTapSettings = false
        let view = ConversationsListToolbarActionsView {
            didTapSettings = true
        }

        view.handleSettingsTap()

        XCTAssertTrue(didTapSettings)
    }
}
