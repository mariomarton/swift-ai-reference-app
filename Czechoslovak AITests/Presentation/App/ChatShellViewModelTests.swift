import SwiftUI
import XCTest
@testable import Czechoslovak_AI

@MainActor
private final class SidebarConversationsManagerMock: SidebarConversationsManaging {
    var selectedConversationID: UUID?
    var createdConversationID: UUID?
    private(set) var createCallsCount = 0
    private(set) var receivedTitles: [String?] = []

    func createConversation(title: String?) async {
        createCallsCount += 1
        receivedTitles.append(title)
        selectedConversationID = createdConversationID
    }
}

@MainActor
final class ChatShellViewModelTests: XCTestCase {
    func testBootstrapCreatesConversationAndSelectsDetail() async {
        let manager = SidebarConversationsManagerMock()
        let createdID = UUID()
        manager.createdConversationID = createdID
        let sut = ChatShellViewModel()

        await sut.bootstrapIfNeeded(using: manager, isCompactLayout: false)

        XCTAssertEqual(manager.createCallsCount, 1)
        XCTAssertEqual(manager.receivedTitles, [nil])
        XCTAssertEqual(sut.activeConversationID, createdID)
        XCTAssertEqual(sut.columnVisibility, .detailOnly)
        XCTAssertNil(manager.selectedConversationID)
    }

    func testBootstrapRunsOnlyOnce() async {
        let manager = SidebarConversationsManagerMock()
        manager.createdConversationID = UUID()
        let sut = ChatShellViewModel()

        await sut.bootstrapIfNeeded(using: manager, isCompactLayout: false)
        await sut.bootstrapIfNeeded(using: manager, isCompactLayout: false)

        XCTAssertEqual(manager.createCallsCount, 1)
    }

    func testHandleConversationSelectionHidesSidebar() {
        let sut = ChatShellViewModel()
        sut.showSidebar()
        let selectedID = UUID()

        sut.handleConversationSelection(id: selectedID, isCompactLayout: false)

        XCTAssertEqual(sut.activeConversationID, selectedID)
        XCTAssertEqual(sut.columnVisibility, .detailOnly)
    }

    func testShowSidebarAndSearchSetSidebarVisibility() {
        let sut = ChatShellViewModel()

        sut.showSidebar()
        XCTAssertEqual(sut.columnVisibility, .all)

        sut.handleConversationSelection(id: UUID(), isCompactLayout: false)
        XCTAssertEqual(sut.columnVisibility, .detailOnly)

        sut.showSearchInSidebar()
        XCTAssertEqual(sut.columnVisibility, .all)
    }

    func testPresentSettingsOpensSettingsSheet() {
        let sut = ChatShellViewModel()

        sut.presentSettings()

        XCTAssertTrue(sut.isSettingsPresented)
    }

    func testHandleConversationSelectionInCompactPushesChatRoute() {
        let sut = ChatShellViewModel()
        let selectedID = UUID()

        sut.handleConversationSelection(id: selectedID, isCompactLayout: true)

        XCTAssertEqual(sut.activeConversationID, selectedID)
        XCTAssertEqual(sut.compactPath, [.chat(conversationID: selectedID)])
    }

    func testBootstrapInCompactCreatesConversationAndPushesRoute() async {
        let manager = SidebarConversationsManagerMock()
        let createdID = UUID()
        manager.createdConversationID = createdID
        let sut = ChatShellViewModel()

        await sut.bootstrapIfNeeded(using: manager, isCompactLayout: true)

        XCTAssertEqual(sut.activeConversationID, createdID)
        XCTAssertEqual(sut.compactPath, [.chat(conversationID: createdID)])
    }
}
