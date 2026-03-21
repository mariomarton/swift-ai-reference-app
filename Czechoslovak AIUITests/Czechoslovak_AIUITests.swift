//
//  Czechoslovak_AIUITests.swift
//  Czechoslovak AIUITests
//

//

import XCTest

final class Czechoslovak_AIUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Smoke: send message in auto-opened conversation → open sidebar

    private func sidebarButton(in app: XCUIApplication) -> XCUIElement {
        let preferredLabels = ["Show Sidebar", "Hide Sidebar", "Open Sidebar"]
        for label in preferredLabels {
            let button = app.buttons[label]
            if button.exists { return button }
        }

        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Sidebar")).firstMatch
    }

    @MainActor
    func testSmokeCreateAndSendMessage() throws {
        let app = XCUIApplication()
        app.launch()

        // Composer should be visible immediately because app auto-creates and opens a new chat.
        let composer = app.textFields["messageTextField"]
        XCTAssert(composer.waitForExistence(timeout: 5), "Message composer not found")
        composer.tap()
        composer.typeText("Hello smoke test")

        // Send button should be enabled once text is entered
        let sendBtn = app.buttons["sendMessageButton"]
        XCTAssert(sendBtn.waitForExistence(timeout: 3), "Send button not found")
        sendBtn.tap()

        // After send the typed message should be visible in the chat
        let sentMessage = app.staticTexts["Hello smoke test"]
        XCTAssert(sentMessage.waitForExistence(timeout: 10), "Sent message not found after send")

        // Open conversations sidebar from top-left button.
        let openSidebarButton = sidebarButton(in: app)
        XCTAssert(openSidebarButton.waitForExistence(timeout: 3), "Open sidebar button not found")
        openSidebarButton.tap()

        let createBtn = app.buttons["createConversationButton"]
        XCTAssert(createBtn.waitForExistence(timeout: 3), "Conversations sidebar not shown")
    }

    // MARK: - Smoke: conversation + messages persist across relaunch

    @MainActor
    func testConversationPersistsAfterRelaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let openSidebarButton = sidebarButton(in: app)
        XCTAssert(openSidebarButton.waitForExistence(timeout: 5), "Open sidebar button not found on first launch")
        openSidebarButton.tap()

        let createBtn = app.buttons["createConversationButton"]
        XCTAssert(createBtn.waitForExistence(timeout: 3), "Sidebar did not open on first launch")

        // Terminate and relaunch
        app.terminate()
        app.launch()

        let relaunchedSidebarButton = sidebarButton(in: app)
        XCTAssert(relaunchedSidebarButton.waitForExistence(timeout: 5), "Open sidebar button not found after relaunch")
        relaunchedSidebarButton.tap()

        // List should still contain at least one conversation row
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "conversation_"))
        XCTAssert(rows.firstMatch.waitForExistence(timeout: 5), "Conversation did not persist after relaunch")
    }

    // MARK: - Title reload: generated title appears in list after back navigation

    @MainActor
    func testGeneratedTitleAppearsInListAfterReturningFromChat() throws {
        let app = XCUIApplication()
        app.launch()

        let suffix = String(UUID().uuidString.prefix(8))
        let inputText = "SmokeTitle \(suffix)"
        let expectedTitle = "(Stub) Odpoveď na: \(inputText)"

        let composer = app.textFields["messageTextField"]
        XCTAssert(composer.waitForExistence(timeout: 5), "Message composer not found")
        composer.tap()
        composer.typeText(inputText)

        let sendBtn = app.buttons["sendMessageButton"]
        XCTAssert(sendBtn.waitForExistence(timeout: 3), "Send button not found")
        sendBtn.tap()

        let openSidebarButton = sidebarButton(in: app)
        XCTAssert(openSidebarButton.waitForExistence(timeout: 3), "Open sidebar button not found")
        openSidebarButton.tap()

        let createBtn = app.buttons["createConversationButton"]
        XCTAssert(createBtn.waitForExistence(timeout: 3), "Conversations sidebar not shown")

        let generatedTitle = app.staticTexts[expectedTitle]
        XCTAssert(generatedTitle.waitForExistence(timeout: 10), "Generated title did not appear in conversations list")
    }
}
