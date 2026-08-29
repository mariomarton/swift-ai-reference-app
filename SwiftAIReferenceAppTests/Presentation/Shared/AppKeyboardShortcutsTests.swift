import XCTest
@testable import SwiftAIReferenceApp

final class AppKeyboardShortcutsTests: XCTestCase {
    func testDiscoverableShortcutsContainExpectedActions() {
        let shortcuts = AppKeyboardShortcuts.discoverableShortcuts

        XCTAssertEqual(shortcuts.map(\.id), [
            "send-message",
            "new-conversation",
            "toggle-sidebar",
            "open-settings"
        ])
    }

    func testDisplayValueFormatsModifierAndKey() {
        XCTAssertEqual(AppKeyboardShortcuts.sendMessage.displayValue, "↩")
        XCTAssertEqual(AppKeyboardShortcuts.newConversation.displayValue, "⌘N")
        XCTAssertEqual(AppKeyboardShortcuts.toggleSidebar.displayValue, "⌘⌥S")
        XCTAssertEqual(AppKeyboardShortcuts.openSettings.displayValue, "⌘,")
    }
}
