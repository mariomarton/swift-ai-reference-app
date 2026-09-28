import XCTest
@testable import SwiftAIReferenceApp

final class AppKeyboardShortcutsTests: XCTestCase {
    private var shouldAvoidSystemReservedMacShortcuts: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #elseif os(iOS)
        ProcessInfo.processInfo.isiOSAppOnMac
        #else
        false
        #endif
    }

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
        XCTAssertEqual(
            AppKeyboardShortcuts.newConversation.displayValue,
            shouldAvoidSystemReservedMacShortcuts ? "⌘⇧N" : "⌘N"
        )
        XCTAssertEqual(AppKeyboardShortcuts.toggleSidebar.displayValue, "⌘⌥S")
        XCTAssertEqual(
            AppKeyboardShortcuts.openSettings.displayValue,
            shouldAvoidSystemReservedMacShortcuts ? "⌘⇧," : "⌘,"
        )
    }
}
