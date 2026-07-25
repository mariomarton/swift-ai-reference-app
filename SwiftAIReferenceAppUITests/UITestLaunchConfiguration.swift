import XCTest

enum UITestLaunchConfiguration {
    static func makeApp(testName: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["SWIFTAIREFERENCEAPP_STORAGE_BACKEND"] = "filebacked"
        app.launchEnvironment["SWIFTAIREFERENCEAPP_STORAGE_ROOT"] = makeStorageRootURL(for: testName).path
        app.launchArguments = [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
        return app
    }

    static func sidebarButton(in app: XCUIApplication) -> XCUIElement {
        let preferredLabels = ["Show Sidebar", "Hide Sidebar", "Open Sidebar"]
        for label in preferredLabels {
            let button = app.buttons[label]
            if button.exists { return button }
        }

        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Sidebar")).firstMatch
    }

    static func conversationRow(in app: XCUIApplication, matching title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", title)).firstMatch
    }

    static func conversationsList(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "conversationsList").firstMatch
    }

    private static func makeStorageRootURL(for testName: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftAIReferenceAppUITests", isDirectory: true)
            .appendingPathComponent(testName, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
