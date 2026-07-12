import XCTest
import UIKit
@testable import SwiftAIReferenceApp

@MainActor
final class SelectableAssistantTextViewTests: XCTestCase {
    func testConfiguredTextViewIsSelectableAndNotEditable() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()

        XCTAssertTrue(view.isSelectable)
        XCTAssertFalse(view.isEditable)
        XCTAssertFalse(view.isScrollEnabled)
    }

    func testConfiguredTextViewUsesBubbleFriendlyLayoutDefaults() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()

        XCTAssertEqual(view.textContainerInset, .zero)
        XCTAssertEqual(view.textContainer.lineFragmentPadding, 0)
        XCTAssertTrue(view.textContainer.widthTracksTextView)
        XCTAssertEqual(view.backgroundColor, .clear)
    }

    func testConfiguredTextViewSupportsDynamicTypeBodyFont() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()

        XCTAssertTrue(view.adjustsFontForContentSizeCategory)
        XCTAssertEqual(view.font?.textStyle, .body)
    }

    func testApplyContentPreservesSelectionWhenTextIsUnchanged() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()
        view.text = "Bratislava je hlavne mesto Slovenska."
        view.textColor = .label
        view.selectedRange = NSRange(location: 5, length: 10)

        SelectableAssistantTextView.applyContent(
            text: "Bratislava je hlavne mesto Slovenska.",
            textColor: .label,
            to: view
        )

        XCTAssertEqual(view.selectedRange.location, 5)
        XCTAssertEqual(view.selectedRange.length, 10)
    }

    func testApplyContentUpdatesTextWhenDifferent() {
        let view = SelectableAssistantTextView.makeConfiguredTextView()
        view.text = "Stary text"

        SelectableAssistantTextView.applyContent(
            text: "Novy text",
            textColor: .label,
            to: view
        )

        XCTAssertEqual(view.text, "Novy text")
    }
}

private extension UIFont {
    var textStyle: TextStyle? {
        guard let style = fontDescriptor.fontAttributes[.textStyle] as? TextStyle else {
            return nil
        }
        return style
    }
}
