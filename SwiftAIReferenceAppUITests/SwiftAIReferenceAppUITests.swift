import XCTest

final class SwiftAIReferenceAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsComposerAndSidebarEntryPoints() throws {
        let app = UITestLaunchConfiguration.makeApp(testName: #function)
        app.launch()

        let composer = app.textFields["messageTextField"]
        XCTAssert(composer.waitForExistence(timeout: 5), "Message composer not found")

        let sidebarButton = UITestLaunchConfiguration.sidebarButton(in: app)
        XCTAssert(sidebarButton.waitForExistence(timeout: 3), "Sidebar button not found")
        sidebarButton.tap()

        let conversationsList = UITestLaunchConfiguration.conversationsList(in: app)
        XCTAssert(conversationsList.waitForExistence(timeout: 3), "Conversations list did not open")
    }

    @MainActor
    func testSendMessageCreatesAssistantResponseAndGeneratedTitle() throws {
        let app = UITestLaunchConfiguration.makeApp(testName: #function)
        app.launch()

        let suffix = String(UUID().uuidString.prefix(8))
        let inputText = "UI test \(suffix)"
        let expectedAssistantText = "Stub response: \(inputText)"

        let composer = app.textFields["messageTextField"]
        XCTAssert(composer.waitForExistence(timeout: 5), "Message composer not found")
        composer.tap()
        composer.typeText(inputText)

        let sendButton = app.buttons["sendMessageButton"]
        XCTAssert(sendButton.waitForExistence(timeout: 3), "Send button not found")
        sendButton.tap()

        let userMessage = app.staticTexts[inputText]
        XCTAssert(userMessage.waitForExistence(timeout: 10), "User message did not appear")

        let assistantMessage = app.staticTexts[expectedAssistantText]
        XCTAssert(assistantMessage.waitForExistence(timeout: 10), "Assistant response did not appear")

        let sidebarButton = UITestLaunchConfiguration.sidebarButton(in: app)
        XCTAssert(sidebarButton.waitForExistence(timeout: 3), "Sidebar button not found")
        sidebarButton.tap()

        let generatedTitle = UITestLaunchConfiguration.conversationRow(in: app, matching: expectedAssistantText)
        XCTAssert(generatedTitle.waitForExistence(timeout: 10), "Generated title did not appear in the conversations list")
    }

    @MainActor
    func testConversationPersistsAcrossRelaunchAndCanBeDeleted() throws {
        let app = UITestLaunchConfiguration.makeApp(testName: #function)
        app.launch()

        let suffix = String(UUID().uuidString.prefix(8))
        let inputText = "Persist \(suffix)"
        let expectedTitle = "Stub response: \(inputText)"

        let composer = app.textFields["messageTextField"]
        XCTAssert(composer.waitForExistence(timeout: 5), "Message composer not found")
        composer.tap()
        composer.typeText(inputText)

        let sendButton = app.buttons["sendMessageButton"]
        XCTAssert(sendButton.waitForExistence(timeout: 3), "Send button not found")
        sendButton.tap()

        let sidebarButton = UITestLaunchConfiguration.sidebarButton(in: app)
        XCTAssert(sidebarButton.waitForExistence(timeout: 3), "Sidebar button not found")
        sidebarButton.tap()

        let persistedRow = UITestLaunchConfiguration.conversationRow(in: app, matching: expectedTitle)
        XCTAssert(persistedRow.waitForExistence(timeout: 10), "Conversation did not appear before relaunch")

        app.terminate()
        app.launch()

        let relaunchedSidebarButton = UITestLaunchConfiguration.sidebarButton(in: app)
        XCTAssert(relaunchedSidebarButton.waitForExistence(timeout: 5), "Sidebar button not found after relaunch")
        relaunchedSidebarButton.tap()

        let relaunchedRow = UITestLaunchConfiguration.conversationRow(in: app, matching: expectedTitle)
        XCTAssert(relaunchedRow.waitForExistence(timeout: 10), "Conversation did not persist after relaunch")

        relaunchedRow.swipeLeft()

        let deleteButton = app.buttons["Delete"]
        XCTAssert(deleteButton.waitForExistence(timeout: 5), "Delete action not shown")
        deleteButton.tap()

        XCTAssertFalse(
            relaunchedRow.waitForExistence(timeout: 3),
            "Conversation still present after delete"
        )
    }
}
