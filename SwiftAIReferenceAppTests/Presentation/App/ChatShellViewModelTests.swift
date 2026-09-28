import SwiftUI
import XCTest
@testable import SwiftAIReferenceApp

@MainActor
private final class SidebarConversationsManagerMock: SidebarConversationsManaging {
    var selectedConversationID: UUID?
    var conversationIDToStart = UUID()
    private(set) var startCallsCount = 0

    func startConversation() -> UUID {
        startCallsCount += 1
        selectedConversationID = conversationIDToStart
        return conversationIDToStart
    }
}

@MainActor
final class ChatShellViewModelTests: XCTestCase {
    func testBootstrapCreatesConversationAndSelectsDetail() async {
        let manager = SidebarConversationsManagerMock()
        let createdID = UUID()
        manager.conversationIDToStart = createdID
        let sut = ChatShellViewModel()

        await sut.bootstrapIfNeeded(using: manager, isCompactLayout: false)

        XCTAssertEqual(manager.startCallsCount, 1)
        XCTAssertEqual(sut.activeConversationID, createdID)
        XCTAssertEqual(sut.columnVisibility, .detailOnly)
        XCTAssertNil(manager.selectedConversationID)
    }

    func testBootstrapRunsOnlyOnce() async {
        let manager = SidebarConversationsManagerMock()
        manager.conversationIDToStart = UUID()
        let sut = ChatShellViewModel()

        await sut.bootstrapIfNeeded(using: manager, isCompactLayout: false)
        await sut.bootstrapIfNeeded(using: manager, isCompactLayout: false)

        XCTAssertEqual(manager.startCallsCount, 1)
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

    func testConversationsListSettingsButtonIsHiddenWhenSidebarAndChatAreVisibleTogether() {
        let sut = ChatShellViewModel()
        sut.showSidebar()

        let shouldShowSettingsButton = sut.shouldShowConversationsListSettingsButton(isCompactLayout: false)

        XCTAssertFalse(shouldShowSettingsButton)
    }

    func testConversationsListSettingsButtonIsShownInCompactLayout() {
        let sut = ChatShellViewModel()
        sut.showSidebar()

        let shouldShowSettingsButton = sut.shouldShowConversationsListSettingsButton(isCompactLayout: true)

        XCTAssertTrue(shouldShowSettingsButton)
    }

    func testConversationsListSettingsButtonIsShownWhenSidebarIsNotVisible() {
        let sut = ChatShellViewModel()

        let shouldShowSettingsButton = sut.shouldShowConversationsListSettingsButton(isCompactLayout: false)

        XCTAssertTrue(shouldShowSettingsButton)
    }

    func testConversationsListSettingsButtonIsHiddenInDoubleColumnSplitState() {
        let sut = ChatShellViewModel()
        sut.columnVisibility = .doubleColumn

        let shouldShowSettingsButton = sut.shouldShowConversationsListSettingsButton(isCompactLayout: false)

        XCTAssertFalse(shouldShowSettingsButton)
    }

    func testConversationsListSettingsButtonIsHiddenInAutomaticSplitState() {
        let sut = ChatShellViewModel()
        sut.columnVisibility = .automatic

        let shouldShowSettingsButton = sut.shouldShowConversationsListSettingsButton(isCompactLayout: false)

        XCTAssertFalse(shouldShowSettingsButton)
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
        manager.conversationIDToStart = createdID
        let sut = ChatShellViewModel()

        await sut.bootstrapIfNeeded(using: manager, isCompactLayout: true)

        XCTAssertEqual(sut.activeConversationID, createdID)
        XCTAssertEqual(sut.compactPath, [.chat(conversationID: createdID)])
    }
}
